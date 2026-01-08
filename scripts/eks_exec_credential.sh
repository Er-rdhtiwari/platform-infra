#!/usr/bin/env bash
set -euo pipefail

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI not found."
  exit 1
fi

python_cmd=""
if command -v python3 >/dev/null 2>&1; then
  python_cmd="python3"
elif command -v python >/dev/null 2>&1; then
  python_cmd="python"
else
  echo "python3 (or python) is required to normalize ExecCredential output."
  exit 1
fi

args=("$@")
has_output="false"

for arg in "${args[@]}"; do
  if [[ "$arg" == "--output" || "$arg" == "--output=json" ]]; then
    has_output="true"
    break
  fi
done

if [[ "$has_output" == "false" ]]; then
  args+=("--output" "json")
fi

aws "${args[@]}" | "$python_cmd" - <<'PY'
import json
import sys

data = json.load(sys.stdin)
if not isinstance(data, dict):
    raise SystemExit("Unexpected ExecCredential output")

data.setdefault("kind", "ExecCredential")
data["apiVersion"] = "client.authentication.k8s.io/v1"

json.dump(data, sys.stdout)
PY
