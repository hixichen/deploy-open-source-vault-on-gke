#!/bin/bash
set -exuo pipefail

case $1 in
     dev)
          GCP_PROJECT=myproject
          ;;
     staging|production|prod)
          GCP_PROJECT=myproject-prod
          ;;
     *)
          echo "Unrecognized ENV_TAG $2."
          echo "Usage: push-audit-image.sh [stage]"
          exit
esac




IMAGE_TAG=$1
[ -z "$IMAGE_TAG" ] && { echo "Empty image tag $IMAGE_TAG " ; exit -1 ; }

docker tag oss-vault-audit:latest us-west1-docker.pkg.dev/$GCP_PROJECT/myteam/oss-vault-audit:latest
docker tag oss-vault-audit:latest us-west1-docker.pkg.dev/$GCP_PROJECT/myteam/oss-vault-audit:$IMAGE_TAG


gcloud auth configure-docker us-west1-docker.pkg.dev
docker push us-west1-docker.pkg.dev/$GCP_PROJECT/myteam/oss-vault-audit:latest
docker push us-west1-docker.pkg.dev/$GCP_PROJECT/myteam/oss-vault-audit:$IMAGE_TAG

echo "succeed"
