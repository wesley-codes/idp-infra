#!/usr/bin/env bash
#
# Bootstrap the Terraform remote-state backend:
#   - an S3 bucket to hold Terraform state
#   - a DynamoDB table to hold the state lock
#
# Run this ONCE, before the first `terraform init`. Credentials come from aws-vault,
# so run the whole script under it:
#
#   aws-vault exec terraform -- bash bootstrap/create-backend.sh
#
# The create-* calls will error if a resource already exists — that's fine to ignore
# on a re-run.

set -euo pipefail

# ----------------------- EDIT THESE -----------------------
AWS_REGION="us-east-1"                                  # your region
TF_STATE_BUCKET="idp-infra-tfstate-meka-${AWS_REGION}"       # MUST be globally unique
TF_LOCK_TABLE="idp-infra-tf-locks"
# ----------------------------------------------------------

echo "Region : $AWS_REGION"
echo "Bucket : $TF_STATE_BUCKET"
echo "Table  : $TF_LOCK_TABLE"
echo

# ======== S3 bucket to hold state (us-east-1 is special: no LocationConstraint allowed) ========
if [ "$AWS_REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION"
else
  aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"
fi

# ======== Versioning — keep old state so a bad apply can be recovered ========
aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# ======== Block ALL public access — state can contain secrets ========
aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# ========= Default encryption at rest (AES-256) =========
aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# ======== DynamoDB lock table — the key MUST be named LockID =========
aws dynamodb create-table --table-name "$TF_LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region "$AWS_REGION"

echo
echo "Backend created."
echo "Next: copy these values into environments/dev/backend.tf, then run 'terraform init' there."
