# Install OSS Vault with Helm


```
export 

helm repo remove hashicorp & helm repo add hashicorp https://helm.releases.hashicorp.com


# find the right version
helm search repo hashicorp/vault -l

# test and debug
helm install --namespace dev  vault hashicorp/vault --version 0.19.0 --values values-dev.yaml --dry-run --debug > temp.yaml

# generate yaml
helm template vault ./vault-helm --values values-dev.yaml --version 0.19.0 > generated-test.yaml

# install

// create tls cert
./vault-csr-tls.sh dev

// create configmap
kubectl apply -f audit-configmap.yaml



helm install \
  --namespace dev vault hashicorp/vault \
  --version 0.19.0 \
  --values values-dev.yaml \
  --set server.serviceAccount.annotations."iam\.gke\.io/gcp-service-account"=gke-dev-vault@myproject.iam.gserviceaccount.com


helm install --namespace dev vault hashicorp/vault --version 0.19.0 --values values-dev.yaml


//(optional:) you can annotate service account with seperate
kubectl annotate serviceaccount vault iam.gke.io/gcp-service-account=gke-dev-vault@myproject.iam.gserviceaccount.com


# upgrade
helm upgrade --namespace dev vault hashicorp/vault --version 0.19.0 --values values-dev.yaml
```

**issues compared kustomize:**


1. config to args:

Failed to inseat this line to args: `[ -n "${VAULT_K8S_NAMESPACE}" ] && sed -Ei "s|VAULT_K8S_NAMESPACE|${VAULT_K8S_NAMESPACE?}|g" /tmp/storageconfig.hcl;`

Thus, have to give fixed namespace when autojoin: 
```
auto_join = "provider=k8s label_selector=\"app.kubernetes.io/name=vault,component=server\" namespace=\"dev\" "
```


Refer: [helm configuration] (https://www.vaultproject.io/docs/platform/k8s/helm/configuration)