#!/usr/bin/env bash
set -ex

case $1 in
     dev)
          TARGET_ACCOUNT=myproject
          TARGET_ENV=dev
          ;;
     staging)
          TARGET_ACCOUNT=myproject-prod
          TARGET_ENV=staging
          ;;
     production|prod)
          TARGET_ACCOUNT=myproject-prod
          TARGET_ENV=production
          ;;
     *)
          echo "Unrecognized environment $1."
          echo "Usage: vault-workloadidentity.sh [dev|staging|prod]"
          exit
esac

export GCP_PROJECT=$TARGET_ACCOUNT
export GCP_SA=gke-${TARGET_ENV}-vault
export K8S_SA=vault
export K8S_NS=${TARGET_ENV}

gcloud iam service-accounts create ${GCP_SA} --display-name=${GCP_SA} || true


gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GCP_PROJECT}.svc.id.goog[${K8S_NS}/${K8S_SA}]" \
  ${GCP_SA}@${GCP_PROJECT}.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
  --member "serviceAccount:${GCP_SA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  --role roles/cloudkms.cryptoKeyEncrypterDecrypter



# if k8s sa is not exist, you may need to run this again once k8s sa is created.
 kubectl annotate serviceaccount ${K8S_SA} \
  iam.gke.io/gcp-service-account="${GCP_SA}@${GCP_PROJECT}.iam.gserviceaccount.com" \
  -n ${K8S_NS}