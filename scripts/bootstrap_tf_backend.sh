#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: bootstrap_tf_backend.sh --region <region> [options]

Options:
  --bucket        S3 bucket name for Terraform state (default: rdhcloudresource-org-terraform-state).
  --region        AWS region for the bucket and DynamoDB table.
  --table         DynamoDB table name for state locking (default: rdhcloudresource-org-terraform-locks).
  --kms-key-id    Optional KMS key ID/ARN for S3 and DynamoDB encryption.
  --profile       Optional AWS CLI profile name.
  --env           Optional environment name (dev|stage|prod) used in output examples.
  --prefix        Optional state key prefix (default: platform-infra).
  -h, --help      Show this help.
USAGE
}

bucket="rdhcloudresource-org-terraform-state"
region=""
table="rdhcloudresource-org-terraform-locks"
kms_key_id=""
profile=""
env_name=""
prefix="platform-infra"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      bucket="$2"
      shift 2
      ;;
    --region)
      region="$2"
      shift 2
      ;;
    --table)
      table="$2"
      shift 2
      ;;
    --kms-key-id)
      kms_key_id="$2"
      shift 2
      ;;
    --profile)
      profile="$2"
      shift 2
      ;;
    --env)
      env_name="$2"
      shift 2
      ;;
    --prefix)
      prefix="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$region" ]]; then
  echo "Missing required argument: --region."
  usage
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI is required but not found."
  exit 1
fi

aws_args=()
if [[ -n "$profile" ]]; then
  aws_args+=(--profile "$profile")
fi

if aws s3api head-bucket --bucket "$bucket" "${aws_args[@]}" >/dev/null 2>&1; then
  echo "S3 bucket already exists: $bucket"
else
  echo "Creating S3 bucket: $bucket"
  if [[ "$region" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$bucket" --region "$region" "${aws_args[@]}"
  else
    aws s3api create-bucket --bucket "$bucket" --region "$region" \
      --create-bucket-configuration LocationConstraint="$region" "${aws_args[@]}"
  fi
fi

aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled "${aws_args[@]}"
aws s3api put-public-access-block --bucket "$bucket" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  "${aws_args[@]}"

if [[ -n "$kms_key_id" ]]; then
  aws s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration "{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"aws:kms\",\"KMSMasterKeyID\":\"$kms_key_id\"}}]}" \
    "${aws_args[@]}"
else
  aws s3api put-bucket-encryption --bucket "$bucket" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
    "${aws_args[@]}"
fi

echo "Ensuring DynamoDB table exists: $table"
if aws dynamodb describe-table --table-name "$table" "${aws_args[@]}" >/dev/null 2>&1; then
  echo "DynamoDB table already exists: $table"
else
  if [[ -n "$kms_key_id" ]]; then
    aws dynamodb create-table \
      --table-name "$table" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId="$kms_key_id" \
      "${aws_args[@]}"
  else
    aws dynamodb create-table \
      --table-name "$table" \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST \
      --sse-specification Enabled=true \
      "${aws_args[@]}"
  fi
fi

key_prefix="$prefix"
if [[ -n "$env_name" ]]; then
  env_print="$env_name"
else
  env_print="ENV"
fi
backend_key="${key_prefix}/${env_print}/terraform.tfstate"

cat <<EOM

Backend bootstrap complete.

Next steps (example):
  terraform -chdir=envs/${env_print} init \
    -backend-config="bucket=${bucket}" \
    -backend-config="key=${backend_key}" \
    -backend-config="region=${region}" \
    -backend-config="dynamodb_table=${table}" \
    -backend-config="encrypt=true"${kms_key_id:+ \
    -backend-config="kms_key_id=${kms_key_id}"}
EOM
