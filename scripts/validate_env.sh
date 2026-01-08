#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: validate_env.sh [--env <dev|stage|prod>] [--action <plan|apply|destroy>] [--region <aws-region>] [--skip-identity]

Options:
  --env            Environment name. Can also use ENV.
  --action         Terraform action. Can also use ACTION.
  --region         AWS region. Can also use AWS_REGION.
  --skip-identity  Skip aws sts get-caller-identity check.
  -h, --help       Show this help.
USAGE
}

env_name="${ENV:-}"
action="${ACTION:-}"
region="${AWS_REGION:-}"
skip_identity="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      env_name="$2"
      shift 2
      ;;
    --action)
      action="$2"
      shift 2
      ;;
    --region)
      region="$2"
      shift 2
      ;;
    --skip-identity)
      skip_identity="true"
      shift 1
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

if [[ -z "$env_name" || -z "$action" || -z "$region" ]]; then
  echo "ENV, ACTION, and AWS_REGION are required."
  usage
  exit 1
fi

if [[ "$env_name" != "dev" && "$env_name" != "stage" && "$env_name" != "prod" ]]; then
  echo "ENV must be dev, stage, or prod."
  exit 1
fi

if [[ "$action" != "plan" && "$action" != "apply" && "$action" != "destroy" ]]; then
  echo "ACTION must be plan, apply, or destroy."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found."
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found."
  exit 1
fi

version_ge() {
  local IFS=.
  local i
  local -a ver1=($1)
  local -a ver2=($2)

  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done

  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 0
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 1
    fi
  done

  return 0
}

required_tf_version="1.5.0"
installed_tf_version=$(terraform version -json 2>/dev/null | awk -F'"' '/terraform_version/ {print $4; exit}')

if [[ -z "$installed_tf_version" ]]; then
  echo "Unable to determine Terraform version."
  exit 1
fi

if ! version_ge "$installed_tf_version" "$required_tf_version"; then
  echo "Terraform ${required_tf_version}+ is required. Found: ${installed_tf_version}."
  exit 1
fi

if [[ "$skip_identity" != "true" ]]; then
  aws sts get-caller-identity >/dev/null
fi

echo "Environment validation passed for ${env_name} (${region}) with action ${action}."
