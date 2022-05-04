#!/bin/bash


vault policy write oss-vault-cronjob -<<EOF
path "sys/leader" {
    capabilities = ["read"]
}

path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
EOF


vault auth enable approle

# replace secret_id_bound_cidrs with POD cidr
vault write auth/approle/role/oss-vault-cronjob token_policies="oss-vault-cronjob" \
            secret_id_bound_cidrs="0.0.0.0/0" \
            bind_secret_id=false

VAULT_APPROLE_ROLE_ID=$(vault read -field=role_id auth/approle/role/oss-vault-cronjob/role-id)


 kubectl delete secret oss-vault-cronjob-roleid --ignore-not-found
 kubectl create secret generic oss-vault-cronjob-roleid \
   --from-literal=VAULT_APPROLE_ROLE_ID=$VAULT_APPROLE_ROLE_ID

GCP_SA=gke-dev-vault@myproject.iam.gserviceaccount.com
gsutil iam ch serviceAccount:${GCP_SA}:roles/storage.admin gs://vault-backup-snapshot

# Test cronjob with job
#kubectl create job --from=cronjob/oss-vault-cronjob test