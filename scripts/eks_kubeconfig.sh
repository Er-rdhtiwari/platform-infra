#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: eks_kubeconfig.sh [options]

Options:
  --env              Environment name (dev|stage|prod) to read Terraform outputs.
  --cluster          EKS cluster name (if not using --env).
  --region           AWS region (if not using --env).
  --kubeconfig       Path to kubeconfig file (default: ~/.kube/config or $KUBECONFIG).
  --profile          Optional AWS CLI profile name.
  --force-api-version  Force exec apiVersion (v1, v1beta1, v1alpha1).
  -h, --help         Show this help.
USAGE
}

env_name=""
cluster_name=""
region=""
profile=""
force_api_version=""
kubeconfig_path="${KUBECONFIG:-$HOME/.kube/config}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      env_name="$2"
      shift 2
      ;;
    --cluster)
      cluster_name="$2"
      shift 2
      ;;
    --region)
      region="$2"
      shift 2
      ;;
    --kubeconfig)
      kubeconfig_path="$2"
      shift 2
      ;;
    --profile)
      profile="$2"
      shift 2
      ;;
    --force-api-version)
      force_api_version="$2"
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

if [[ -n "$env_name" ]]; then
  if ! command -v terraform >/dev/null 2>&1; then
    echo "terraform not found, required to read outputs for --env."
    exit 1
  fi

  cluster_name=$(terraform -chdir="envs/${env_name}" output -raw cluster_name)
  region=$(terraform -chdir="envs/${env_name}" output -raw region)
fi

if [[ -z "$cluster_name" || -z "$region" ]]; then
  echo "cluster and region are required (set --env or provide --cluster and --region)."
  usage
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found."
  exit 1
fi

aws_args=(--name "$cluster_name" --region "$region" --kubeconfig "$kubeconfig_path")
if [[ -n "$profile" ]]; then
  aws_args+=(--profile "$profile")
fi

aws eks update-kubeconfig "${aws_args[@]}"

select_api_version() {
  if [[ -n "$force_api_version" ]]; then
    case "$force_api_version" in
      v1|v1beta1|v1alpha1)
        echo "client.authentication.k8s.io/${force_api_version}"
        return 0
        ;;
      *)
        echo "Invalid --force-api-version value: $force_api_version"
        exit 1
        ;;
    esac
  fi

  if command -v kubectl >/dev/null 2>&1; then
    local client_version
    client_version=$(kubectl version --client -o json 2>/dev/null | awk -F'"' '/gitVersion/ {print $4; exit}')
    if [[ -n "$client_version" ]]; then
      local ver major minor
      ver=${client_version#v}
      major=${ver%%.*}
      minor=${ver#*.}
      minor=${minor%%.*}
      minor=${minor%%[^0-9]*}

      if [[ "$major" -ge 2 ]]; then
        echo "client.authentication.k8s.io/v1"
        return 0
      fi
      if [[ "$major" -eq 1 && -n "$minor" && "$minor" -ge 26 ]]; then
        echo "client.authentication.k8s.io/v1"
        return 0
      fi
    fi
  fi

  echo "client.authentication.k8s.io/v1beta1"
}

api_version=$(select_api_version)

if [[ ! -f "$kubeconfig_path" ]]; then
  echo "kubeconfig not found at $kubeconfig_path"
  exit 1
fi

update_kubeconfig_api_version() {
  local target="$1"
  local file="$2"

  if command -v perl >/dev/null 2>&1; then
    case "$target" in
      client.authentication.k8s.io/v1)
        perl -pi -e 's#client.authentication.k8s.io/v1alpha1#client.authentication.k8s.io/v1#g; s#client.authentication.k8s.io/v1beta1#client.authentication.k8s.io/v1#g' "$file"
        ;;
      client.authentication.k8s.io/v1beta1)
        perl -pi -e 's#client.authentication.k8s.io/v1alpha1#client.authentication.k8s.io/v1beta1#g' "$file"
        ;;
      client.authentication.k8s.io/v1alpha1)
        perl -pi -e 's#client.authentication.k8s.io/v1beta1#client.authentication.k8s.io/v1alpha1#g' "$file"
        ;;
    esac
    return 0
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
import re
from pathlib import Path
path = Path(r"$file")
data = path.read_text()
if "$target" == "client.authentication.k8s.io/v1":
    data = re.sub(r"client\.authentication\.k8s\.io/v1alpha1", "client.authentication.k8s.io/v1", data)
    data = re.sub(r"client\.authentication\.k8s\.io/v1beta1", "client.authentication.k8s.io/v1", data)
elif "$target" == "client.authentication.k8s.io/v1beta1":
    data = re.sub(r"client\.authentication\.k8s\.io/v1alpha1", "client.authentication.k8s.io/v1beta1", data)
elif "$target" == "client.authentication.k8s.io/v1alpha1":
    data = re.sub(r"client\.authentication\.k8s\.io/v1beta1", "client.authentication.k8s.io/v1alpha1", data)
path.write_text(data)
PY
    return 0
  fi

  echo "Neither perl nor python3 is available to update kubeconfig."
  exit 1
}

update_kubeconfig_api_version "$api_version" "$kubeconfig_path"

echo "Updated kubeconfig exec apiVersion to ${api_version} in ${kubeconfig_path}."
