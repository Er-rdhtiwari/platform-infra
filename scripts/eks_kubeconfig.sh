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
  --no-wrapper       Do not replace exec command with the repo wrapper.
  -h, --help         Show this help.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper_path="${script_dir}/eks_exec_credential.sh"

env_name=""
cluster_name=""
region=""
profile=""
force_api_version=""
kubeconfig_path="${KUBECONFIG:-$HOME/.kube/config}"
use_wrapper="true"

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
    --no-wrapper)
      use_wrapper="false"
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

ensure_interactive_mode() {
  local file="$1"
  local wrapper="$2"

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
from pathlib import Path

path = Path(r"$file")
data = path.read_text()
lines = data.splitlines()
out = []

def indent_len(line: str) -> int:
    return len(line) - len(line.lstrip(" "))

in_exec = False
exec_indent = 0
has_interactive = False
command_aws = False

def insert_interactive():
    if command_aws and not has_interactive:
        out.append(" " * (exec_indent + 2) + "interactiveMode: IfAvailable")

for line in lines:
    stripped = line.lstrip()
    if in_exec and stripped and indent_len(line) <= exec_indent:
        insert_interactive()
        in_exec = False
        exec_indent = 0
        has_interactive = False
        command_aws = False

    if not in_exec and stripped.startswith("exec:"):
        in_exec = True
        exec_indent = indent_len(line)
        has_interactive = False
        command_aws = False
        out.append(line)
        continue

    if in_exec:
        if stripped.startswith("interactiveMode:"):
            has_interactive = True
        if stripped.startswith("command:"):
            value = stripped.split("command:", 1)[1].strip()
            if value == "aws" or value == r"$wrapper":
                command_aws = True

    out.append(line)

if in_exec:
    insert_interactive()

path.write_text("\\n".join(out) + ("\\n" if data.endswith("\\n") else ""))
PY
    return 0
  fi

  if command -v perl >/dev/null 2>&1; then
    perl - <<'PERL' "$file" "$wrapper"
use strict;
use warnings;

my $file = shift;
my $wrapper = shift;
open my $fh, '<', $file or die "Unable to read $file: $!";
my @lines = <$fh>;
close $fh;

my @out;
my ($in_exec, $exec_indent, $has_interactive, $command_aws) = (0, 0, 0, 0);

sub insert_interactive {
  if ($command_aws && !$has_interactive) {
    push @out, (' ' x ($exec_indent + 2)) . "interactiveMode: IfAvailable\n";
  }
}

foreach my $line (@lines) {
  my ($indent) = ($line =~ /^(\s*)/);
  my $indent_len = length($indent);
  (my $stripped = $line) =~ s/^\s+//;
  chomp $stripped;

  if ($in_exec && $stripped ne '' && $indent_len <= $exec_indent) {
    insert_interactive();
    ($in_exec, $exec_indent, $has_interactive, $command_aws) = (0, 0, 0, 0);
  }

  if (!$in_exec && $line =~ /^\s*exec:\s*$/) {
    $in_exec = 1;
    $exec_indent = $indent_len;
    $has_interactive = 0;
    $command_aws = 0;
    push @out, $line;
    next;
  }

  if ($in_exec) {
    $has_interactive = 1 if $line =~ /^\s*interactiveMode:\s*/;
    if ($line =~ /^\s*command:\s*(\S+)\s*$/) {
      $command_aws = 1 if $1 eq 'aws' || $1 eq $wrapper;
    }
  }

  push @out, $line;
}

insert_interactive() if $in_exec;

open my $fh_out, '>', $file or die "Unable to write $file: $!";
print $fh_out @out;
close $fh_out;
PERL
    return 0
  fi

  echo "Neither python3 nor perl is available to update kubeconfig."
  exit 1
}

ensure_interactive_mode "$kubeconfig_path" "$wrapper_path"

ensure_exec_wrapper() {
  local file="$1"
  local wrapper="$2"

  if [[ ! -x "$wrapper" ]]; then
    echo "Exec wrapper not found or not executable: $wrapper"
    exit 1
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
from pathlib import Path

path = Path(r"$file")
wrapper = "$wrapper"
data = path.read_text()
lines = data.splitlines()
out = []

def indent_len(line: str) -> int:
    return len(line) - len(line.lstrip(" "))

in_exec = False
exec_indent = 0

for line in lines:
    stripped = line.lstrip()
    if in_exec and stripped and indent_len(line) <= exec_indent:
        in_exec = False
        exec_indent = 0

    if not in_exec and stripped.startswith("exec:"):
        in_exec = True
        exec_indent = indent_len(line)
        out.append(line)
        continue

    if in_exec and stripped.startswith("command:"):
        value = stripped.split("command:", 1)[1].strip()
        if value == "aws":
            line = " " * (exec_indent + 2) + "command: " + wrapper

    out.append(line)

path.write_text("\\n".join(out) + ("\\n" if data.endswith("\\n") else ""))
PY
    return 0
  fi

  if command -v perl >/dev/null 2>&1; then
    perl - <<'PERL' "$file" "$wrapper"
use strict;
use warnings;

my $file = shift;
my $wrapper = shift;

open my $fh, '<', $file or die "Unable to read $file: $!";
my @lines = <$fh>;
close $fh;

my @out;
my ($in_exec, $exec_indent) = (0, 0);

foreach my $line (@lines) {
  my ($indent) = ($line =~ /^(\s*)/);
  my $indent_len = length($indent);
  (my $stripped = $line) =~ s/^\s+//;
  chomp $stripped;

  if ($in_exec && $stripped ne '' && $indent_len <= $exec_indent) {
    $in_exec = 0;
    $exec_indent = 0;
  }

  if (!$in_exec && $line =~ /^\s*exec:\s*$/) {
    $in_exec = 1;
    $exec_indent = $indent_len;
    push @out, $line;
    next;
  }

  if ($in_exec && $line =~ /^\s*command:\s*(\S+)\s*$/) {
    if ($1 eq 'aws') {
      $line = (' ' x ($exec_indent + 2)) . "command: $wrapper\n";
    }
  }

  push @out, $line;
}

open my $fh_out, '>', $file or die "Unable to write $file: $!";
print $fh_out @out;
close $fh_out;
PERL
    return 0
  fi

  echo "Neither python3 nor perl is available to update kubeconfig."
  exit 1
}

if [[ "$use_wrapper" == "true" ]]; then
  ensure_exec_wrapper "$kubeconfig_path" "$wrapper_path"
fi

echo "Updated kubeconfig exec apiVersion to ${api_version}, ensured interactiveMode, and set exec wrapper in ${kubeconfig_path}."
