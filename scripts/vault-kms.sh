#!/usr/bin/env bash
set -ex

export region="us-west1"
export key_ring="vault-keyring"
export crypto_key="unseal-key-dev"

gcloud kms keyrings create ${key_ring} --location ${region}
gcloud kms keys create $crypto_key --location ${region} --keyring $key_ring  --purpose "encryption"
