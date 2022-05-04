# Open Source Vault Cookbook
> This cook targets for deploying open source Vault on GKE.

## General tools

```bash
brew install helm kustomize
```

**optional:** add these aliases to your `.bashrc` or `.zshrc` file.

```bash
alias kubectl=kubectl
alias ksp=kubens
```

----

## Setup GKE private cluster with bastion host



Refer: 

[terraform config for GKE private cluster](https://sourcegraph.uberinternal.com/code.uber.internal/engsec/vault-terraform-config/-/tree/GKE/cluster/dev)

[terraform registry google module](https://registry.terraform.io/modules/terraform-google-modules/kubernetes-engine/google/latest/submodules/beta-private-cluster-update-variant)

----

## Pre setup on GKE

### **Prerequisite:**

  - Create KMS key:

    ```bash
    ./scripts/vault-kms.sh
    ```
  
  - Create GCP service account:

    ```bash
    ./scripts/vault-workload-identity.sh dev
    ```

  - Create TLS cert as secrets for Vault Pod.

    ```bash
    ./scripts/vault-csr-tls.sh dev
    ```



## Setup with Helm Chart


```

cd helm

helm repo remove hashicorp & helm repo add hashicorp https://helm.releases.hashicorp.com

# find the right version
helm search repo hashicorp/vault -l

# test and debug
helm install --namespace dev  vault hashicorp/vault --version 0.19.0 --values values-dev.yaml --dry-run --debug > temp.yaml

# generate yaml after `git clone https://github.com/hashicorp/vault-helm.git`
helm template vault ./vault-helm --values values-dev.yaml --version 0.19.0 > generated-test.yaml

# install
// create configmap
kubectl apply -f audit-configmap.yaml



helm install \
  --namespace dev vault hashicorp/vault \
  --version 0.19.0 \
  --values values-dev.yaml \
  --set server.serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=gke-dev-vault@myproject.iam.gserviceaccount.com


helm install --namespace dev vault hashicorp/vault --version 0.19.0 --values values-dev.yaml


//(optional:) you can annotate service account with seperate command
kubectl annotate serviceaccount vault iam.gke.io/gcp-service-account=gke-dev-vault@myproject.iam.gserviceaccount.com


# upgrade
helm upgrade --namespace dev vault hashicorp/vault --version 0.19.0 --values values-dev.yaml
```

**compared to kustomize:**


1. config to args:

Failed to inseat this line to args: `[ -n "${VAULT_K8S_NAMESPACE}" ] && sed -Ei "s|VAULT_K8S_NAMESPACE|${VAULT_K8S_NAMESPACE?}|g" /tmp/storageconfig.hcl;`

Thus, have to give fixed namespace when autojoin: 
```
auto_join = "provider=k8s label_selector=\"app.kubernetes.io/name=vault,component=server\" namespace=\"dev\" "
```


Refer: [helm configuration] (https://www.vaultproject.io/docs/platform/k8s/helm/configuration)




## Setup with kustomize 

- **Deploy:**

  ```bash
  cd kustomize
  mkdir generated
  kustomize build ./overlays/dev -o generated
  kubectl apply -f generated
  ```

  - Annotate k8s service account with GCP service account

    ```bash
    kubectl create sa vault -n dev
    kubectl annotate serviceaccount vault iam.gke.io/gcp-service-account=gke-dev-vault@myproject.iam.gserviceaccount.com -n dev
    ```


---

## Features and Notes


### **Auto unseal with gcp KMS**

  permission required for gcp sa:
  
  ```bash
  gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member "serviceAccount:${GCP_SA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter
  ```
  
  sample config:
  
  ```
      seal "gcpckms" {
       project     = "myproject"
       region      = "us-west1"
       key_ring    = "vault-keyring"
       crypto_key  = "unseal-key-dev"
    }
  ```


### **HA mode with integrated storage**


  config:
  
  ```hcl
      storage "raft" {
        path = "/vault/data"
        node_id = "HOSTNAME"
      }
  ```
  
  Note: require mount persistent volume for `/vault/data`. 
  Besides, with security context, the mount volume will automatically chown to `vault:vault`.



### **TLS Cert for Open Source Vault**

  Note:
  > Each pod created by a StatefulSet is assigned an ordinal index (zero-based)

  There are several ways to config TLS cert for Vault:

  1. initial container to generate cert for each Pod
  1. wildcard SAN, one TLS cert for all pods resolved by service.

      ```bash
         cat <<EOF | cfssl genkey - | cfssljson -bare vault-tls
      {
        "hosts": [
          "vault",
          "vault.${NS}",
          "vault.${NS}.svc",
          "vault.${NS}.svc.cluster.local",
          "*.vault-internal",
          "127.0.0.1"
        ],
        "CN": "vault.${NS}.svc",
        "key": {
          "algo": "ecdsa",
          "size": 256
        }
      }
      EOF
      ```

### **Auto Join with k8s provider**

  config:
  
   ```
      storage "raft" {
      retry_join {
        auto_join = "provider=k8s label_selector=\"app=vault,component=server\" namespace=\"VAULT_K8S_NAMESPACE\" "
        leader_tls_servername = "vault"
        auto_join_scheme = "https"
        leader_ca_cert_file = "/vault/cert/vault.ca"
        leader_client_key_file = "/vault/cert/vault.key"
        leader_client_cert_file = "/vault/cert/vault.crt"
      }
    }
   ```

Note:
   
- auto join require `list` role with `namespace`.
- When using TLS, it requires `leader_ca_cert_fil` if CA was not installed to truststore.
- Since TLS cert is configured with wildcard SAN mode, it is important to config `leader_tls_servername` to skip verify the DNS server name from the cert. check [Autojoin with TLS servername](https://www.vaultproject.io/docs/concepts/integrated-storage#autojoin-with-tls-servername)


### **Auditing sidecar container**

  Auditing sidecar will rotate the auditing file which configured to Vault, and send SIGHUP to Vault.


  Notes:

  - better to have seperate persistent volume for auditing log only, but have to mount into both Vault and sidecar container.
  - `pid_file = "/vault/audit/pidfile.pid"` is required for Vault configuration as It can simplify the solution for sidecar figure out the PID of Vault. And, `  shareProcessNamespace: true` is required for k8s deploy yaml.



### **Prometheus Metrics**


1.  Config to Vault:

  ```
      listener "tcp" {
        telemetry {
              unauthenticated_metrics_access = true
        }
      }
      telemetry {
        prometheus_retention_time = "12h"
        disable_hostname = true
      }
  ```

  > Note:

  1. The `/v1/sys/metrics` endpoint is only accessible on active nodes and automatically   disabled on standby nodes. You can enable the `/v1/sys/metrics endpoint on standby nodes   by enabling unauthenticated metrics access.
  1. Pod will have name as label when pulled by Prometheus, hostname is not required when generate metrics from Vault.


1. Config for Prometheus:

  ```yaml
      - job_name: 'vault-pods'
        metrics_path: "/v1/sys/metrics"
        params:
          format: ['prometheus']
        scheme: https
        tls_config:
          insecure_skip_verify: true
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
              - dev
              - staging
              - production
          selectors:
          - role: "pod"
            label: "app=vault"
  ```


### **Backup with CronJob**

  CronJob: creates Jobs on a repeating schedule.
  Backup job will talk to Vault leader node only and take snapshot, then upload to GCS bucket.

1. Leader node only endpoint

  ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: vault-active
     labels:
       app: vault
   spec:
     publishNotReadyAddresses: false
     selector:
       vault-active: "true"
  ```

1. Auth:
    Cronjob requires a way to login into Vault. The eaist way woul dbe use Vault app role id only.
    (you can use role id and secret id, but rotation of secret id is expected.)

    ```bash
      //replace secret_id_bound_cidrs with POD cidr
      vault write auth/approle/role/oss-vault-cronjob token_policies="oss-vault-cronjob" \
               secret_id_bound_cidrs="0.0.0.0/0" \
               bind_secret_id=false
      VAULT_APPROLE_ROLE_ID=$(vault read -field=role_id auth/approle/role/oss-vault-cronjob/role-id)
    ```

1. Permission to upload to GCS bucket.
    Cronjob will be configured to use k8s sa `serviceAccountName: vault`.
    Since k8s SA had been annotated with GCP SA, grant GCP SA with gcs bucket permission would be good enough.

    Example:

    ```bash
    GCP_SA=gke-dev-vault@myproject.iam.gserviceaccount.com
    gsutil iam ch serviceAccount:${GCP_SA}:roles/storage.admin gs://vault-backup-snapshot
    ```

### **Probe/HealthCheck/Update strategy**

1. liveness probe path: `"/v1/sys/health?standbyok=true"`
1. readiness probe path: `"/v1/sys/health?standbyok=true&sealedcode=204&uninitcode=204"`
1. **update strategy:**

    There are two valid update strategies for k8s statefulset: RollingUpdate and OnDelete.

    **RollingUpdate:** is the default for StatefulSets.The RollingUpdate update strategy will update all Pods in a StatefulSet, in reverse ordinal order, while respecting the StatefulSet guarantees. The StatefulSet controller terminates each Pod, and     waits for it to transition to Running and Ready prior to updating the next Pod.

    **OnDelete:** implements the legacy (1.6 and prior) behavior, When you select this update strategy, the StatefulSet     controller will not automatically update Pods when a modification is made to the StatefulSet's `.spec.template` field.

    The Vault StatefulSet uses `OnDelete` update strategy. It is critical to use `OnDelete` instead of RollingUpdate because standbys must be updated before the active primary. The OnDelete strategy is on purpose to prevent the active node from     being upgraded prior to standby nodes when using HA deployments. RollingUpdates do not provide the coordination required to     orchestrate this upgrade pattern.

    **Suggested Update Procedure:**

    - Update non-active nodes:

    ```bash
    kubectl delete pod  --selector="vault-active=false"
    ```
    - Update active node with or without step-down.

    ```bash
    kubectl delete pod  --selector="vault-active=true"
    ```
