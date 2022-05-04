
#!/usr/bin/env bash
set -ex


# brew update && brew install cfssl

NS=$1

alias kubectl=" kubectl"

function cleanup()
{
  rm vault-tls* || true
}

trap cleanup EXIT

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

CSR_NAME=vault.${NS}

## delete first: sync the private key and public key.
kubectl delete csr ${CSR_NAME} --ignore-not-found

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  - system:nodes
  request: $(cat vault-tls.csr | base64 | tr -d '\n')
  signerName: kubernetes.io/kubelet-serving
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF


kubectl describe csr ${CSR_NAME}
kubectl certificate approve  ${CSR_NAME}

sleep 10

kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}' | base64 -d > vault-tls.crt
kubectl delete secret vault-tls --ignore-not-found
kubectl config view --raw --minify --flatten \
   -o jsonpath='{.clusters[].cluster.certificate-authority-data}' | base64 -d > vault-tls-root.ca

kubectl create secret generic vault-tls \
--namespace ${NS} \
--from-file=vault.key=vault-tls-key.pem \
--from-file=vault.crt=vault-tls.crt \
--from-file=vault.ca=vault-tls-root.ca
