# platform-infra

Production-style AWS infrastructure repo that provisions VPC networking, ECR repositories, and an EKS cluster with IRSA enabled. It is organized by environment (dev/stage/prod) and uses a shared module set.

## Prerequisites
- AWS CLI v2 configured with credentials (SSO/assume-role preferred)
- Terraform >= 1.5
- Jenkins agent with `aws` and `terraform` installed (for CI/CD)
- kubectl (optional, for post-apply validation)

## Repository layout
- `envs/dev`, `envs/stage`, `envs/prod`: environment roots
- `modules/vpc`, `modules/ecr`, `modules/eks`: reusable modules
- `scripts/bootstrap_tf_backend.sh`: bootstrap S3 + DynamoDB backend
- `scripts/validate_env.sh`: sanity checks for inputs and tools
- `scripts/eks_kubeconfig.sh`: update kubeconfig and fix exec apiVersion for kubectl

## Bootstrap remote state (S3 + DynamoDB + optional KMS)
1) Create the backend resources:

```bash
./scripts/bootstrap_tf_backend.sh \
  --bucket rdhcloudresource-org-terraform-state \
  --region ap-south-1 \
  --table rdhcloudresource-org-terraform-locks \
  --env dev
```

Optional KMS:

```bash
./scripts/bootstrap_tf_backend.sh \
  --bucket rdhcloudresource-org-terraform-state \
  --region ap-south-1 \
  --table rdhcloudresource-org-terraform-locks \
  --kms-key-id arn:aws:kms:ap-south-1:123456789012:key/abcd-1234 \
  --env dev
```

2) Initialize the backend for an environment (example for dev):

```bash
terraform -chdir=envs/dev init \
  -backend-config="bucket=rdhcloudresource-org-terraform-state" \
  -backend-config="key=platform-infra/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=rdhcloudresource-org-terraform-locks" \
  -backend-config="encrypt=true"
```

## Local workflow (plan/apply)
1) Copy the example tfvars and edit as needed:

```bash
cp envs/dev/terraform.tfvars.example envs/dev/terraform.tfvars
```

Keep `terraform.tfvars` out of version control (see `.gitignore`).

2) Initialize the backend (replace placeholders):

```bash
terraform -chdir=envs/dev init \
  -backend-config="bucket=rdhcloudresource-org-terraform-state" \
  -backend-config="key=platform-infra/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=rdhcloudresource-org-terraform-locks" \
  -backend-config="encrypt=true"
```

3) Validate your environment and tools:

```bash
./scripts/validate_env.sh --env dev --action plan --region ap-south-1
```

4) Run plan:

```bash
terraform -chdir=envs/dev plan
```

5) Apply:

```bash
terraform -chdir=envs/dev apply
```

6) Destroy (if needed):

```bash
terraform -chdir=envs/dev destroy
```

## Jenkins usage
The Jenkins pipeline supports `plan`, `apply`, and `destroy` with an approval gate for `stage` and `prod`.

Required Jenkins parameters:
- `ENV` (dev|stage|prod)
- `ACTION` (plan|apply|destroy)
- `AWS_REGION`

Jenkins environment variables (defaults shown):
- `TF_STATE_BUCKET` (S3 bucket, default: `rdhcloudresource-org-terraform-state`)
- `TF_STATE_DDB_TABLE` (DynamoDB lock table, default: `rdhcloudresource-org-terraform-locks`)
- `TF_STATE_KMS_KEY_ID` (optional, KMS key for encryption)

Example Jenkins run:
- `ENV=stage`
- `ACTION=apply`
- `AWS_REGION=ap-south-1`

## Runbooks
These runbooks make the repository the source of truth for your permanent Jenkins server, with auditable plan/apply flows and centralized remote state/locking.

### Runbook 1: Local CLI workflow (operator)
Use this when you want to test or apply changes directly from your workstation.
1) Validate tools and inputs:

```bash
./scripts/validate_env.sh --env dev --action plan --region ap-south-1
```

2) Initialize the backend (or use `-backend=false` for a dry-run validation):

```bash
terraform -chdir=envs/dev init \
  -backend-config="bucket=rdhcloudresource-org-terraform-state" \
  -backend-config="key=platform-infra/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=rdhcloudresource-org-terraform-locks" \
  -backend-config="encrypt=true"
```

3) Check formatting and validate the configuration:

```bash
terraform fmt -check -recursive
terraform -chdir=envs/dev validate
```

4) Plan and review:

```bash
terraform -chdir=envs/dev plan
```

5) Apply and capture outputs:

```bash
terraform -chdir=envs/dev apply
terraform -chdir=envs/dev output
```

Checkpoint: confirm `cluster_name`, `oidc_issuer_url`, and `private_subnet_ids` for downstream repos.

### Runbook 2: Jenkins admin setup (permanent server)
Use this once to make your long-running Jenkins server the control plane for infra changes.
1) Install tools on the Jenkins agent: `aws`, `terraform`, and optionally `kubectl`.
2) Configure AWS authentication (preferred: instance profile/assume-role). Avoid static keys.
3) Set Jenkins global env vars:
   - `TF_STATE_BUCKET`
   - `TF_STATE_DDB_TABLE`
   - `TF_STATE_KMS_KEY_ID` (optional)
4) Create a Pipeline job (Pipeline from SCM) pointing at this repo and `Jenkinsfile`.
5) Provide environment-specific inputs:
   - Use Jenkins environment variables like `TF_VAR_vpc_cidr`, `TF_VAR_ecr_repositories`, etc.
   - Or store a `terraform.tfvars` file in a secure Jenkins config and copy it into `envs/<env>/` before `init`.
6) Ensure Jenkins permissions:
   - Admins approving stage/prod must have the `input` permission.
   - Restrict who can trigger `apply`/`destroy` in `stage`/`prod`.
7) Validate the job:
   - Run `ENV=dev`, `ACTION=plan` first.
   - For `stage`/`prod`, confirm the approval gate triggers and logs the plan output.

Checkpoint: confirm Jenkins can read/write the state bucket and DynamoDB lock table.

### Runbook 3: Operational checklist (CLI + Jenkins)
Use this for ongoing changes, rollouts, and incident response.
1) Pre-change review:
   - Verify region, CIDR, `az_count`, and `nat_gateway_count` are intentional.
   - Ensure `endpoint_public_access`/`public_access_cidrs` match your security posture.
2) Plan-only review:
   - `terraform plan` locally or `ACTION=plan` in Jenkins.
   - Validate no unexpected resource replacement.
3) Apply with guardrails:
   - Use `stage` to validate first; require Jenkins approval for `prod`.
4) Post-change validation:
   - `aws eks describe-cluster` (cluster status)
   - `aws ecr describe-repositories` (ECR availability)
   - `kubectl get nodes` (worker registration, if network access to the cluster endpoint permits)

Checkpoint: use Terraform outputs to configure platform-addons and app pipelines.

## Outputs (for platform-addons and apps)
After apply, these outputs are available:
- `cluster_name`
- `region`
- `oidc_issuer_url`
- `oidc_provider_arn`
- `vpc_id`
- `private_subnet_ids`
- `ecr_repository_urls`

## Validations after apply
- EKS cluster:

```bash
aws eks describe-cluster --name $(terraform -chdir=envs/dev output -raw cluster_name) --region $(terraform -chdir=envs/dev output -raw region)
```

- ECR repositories:

```bash
aws ecr describe-repositories --region $(terraform -chdir=envs/dev output -raw region)
```

- kubectl connectivity (used by platform-addons):

```bash
./scripts/eks_kubeconfig.sh --env dev

kubectl get nodes
```

Use the Terraform outputs when configuring the platform-addons repo (cluster name, OIDC issuer/provider, and private subnet IDs).

## Troubleshooting
- `AccessDenied` for S3/DynamoDB: verify IAM permissions on state bucket/table and KMS key.
- `BucketAlreadyExists`: S3 bucket names are global; pick a unique name.
- `InvalidClientTokenId`: refresh SSO credentials or assume the correct role.
- `EKS cluster not reachable`: check endpoint access flags and security group rules; verify your public IP is allowed.
- `exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"`: run `./scripts/eks_kubeconfig.sh --env dev` to upgrade the kubeconfig exec apiVersion.
- `kubectl` timeouts: if the cluster endpoint is private, run kubectl from inside the VPC/VPN or enable public access with restricted CIDRs.
- `Node group failed to join`: confirm subnets are private and have NAT or required VPC endpoints.
- `VPC endpoint not supported`: disable STS endpoint via `enable_sts_endpoint = false` for unsupported regions.

## Security notes
- Prefer short-lived credentials (SSO/assume-role); avoid long-lived access keys.
- Remote state is encrypted at rest (S3 SSE or KMS) with DynamoDB locking.
- Tags are applied to all resources for cost allocation and ownership.
- ECR scan-on-push is enabled by default.
