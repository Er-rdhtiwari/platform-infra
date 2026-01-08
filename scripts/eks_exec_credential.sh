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

tmp_out=$(mktemp)
tmp_err=$(mktemp)

set +e
aws "${args[@]}" >"$tmp_out" 2>"$tmp_err"
status=$?
set -e

if [[ $status -ne 0 ]]; then
  cat "$tmp_err" >&2
  rm -f "$tmp_out" "$tmp_err"
  exit $status
fi

if [[ ! -s "$tmp_out" ]]; then
  cat "$tmp_err" >&2
  echo "aws did not return JSON output." >&2
  rm -f "$tmp_out" "$tmp_err"
  exit 1
fi

"$python_cmd" - "$tmp_out" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

try:
    data = json.loads(path.read_text())
except json.JSONDecodeError as exc:
    print(f"Failed to parse JSON from aws output: {exc}", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(data, dict):
    print("Unexpected ExecCredential output.", file=sys.stderr)
    raise SystemExit(1)

data.setdefault("kind", "ExecCredential")
data["apiVersion"] = "client.authentication.k8s.io/v1"

json.dump(data, sys.stdout)
PY

rm -f "$tmp_out" "$tmp_err"
