pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    choice(name: 'ENV', choices: ['dev', 'stage', 'prod'], description: 'Environment')
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
    string(name: 'AWS_REGION', defaultValue: 'ap-south-1', description: 'AWS region')
  }

  environment {
    ENV = "${params.ENV}"
    AWS_REGION = "${params.AWS_REGION}"
    TF_IN_AUTOMATION = "1"
    TF_INPUT = "false"
    TF_VAR_aws_region = "${params.AWS_REGION}"
    TF_VAR_environment = "${params.ENV}"
  }

  stages {
    stage('validateTools') {
      steps {
        sh 'command -v aws'
        sh 'command -v terraform'
        sh 'aws --version'
        sh 'terraform version'
      }
    }

    stage('awsIdentityCheck') {
      steps {
        sh 'aws sts get-caller-identity'
      }
    }

    stage('terraform init/fmt/validate') {
      steps {
        script {
          def stateBucket = env.TF_STATE_BUCKET?.trim()
          if (!stateBucket) {
            stateBucket = 'rdhcloudresource-org-terraform-state'
            env.TF_STATE_BUCKET = stateBucket
          }

          def lockTable = env.TF_STATE_DDB_TABLE?.trim()
          if (!lockTable) {
            lockTable = 'rdhcloudresource-org-terraform-locks'
            env.TF_STATE_DDB_TABLE = lockTable
          }

          def backendArgs = "-backend-config=bucket=${stateBucket} " +
            "-backend-config=key=platform-infra/${params.ENV}/terraform.tfstate " +
            "-backend-config=region=${params.AWS_REGION} " +
            "-backend-config=dynamodb_table=${lockTable} " +
            "-backend-config=encrypt=true"

          if (env.TF_STATE_KMS_KEY_ID?.trim()) {
            backendArgs += " -backend-config=kms_key_id=${env.TF_STATE_KMS_KEY_ID}"
          }

          env.TF_BACKEND_ARGS = backendArgs
        }

        sh 'terraform fmt -check -recursive'
        sh 'terraform -chdir=envs/${ENV} init $TF_BACKEND_ARGS'
        sh 'terraform -chdir=envs/${ENV} validate'
      }
    }

    stage('plan') {
      steps {
        script {
          def destroyFlag = params.ACTION == 'destroy' ? '-destroy' : ''
          sh "terraform -chdir=envs/${ENV} plan ${destroyFlag} -out=tfplan"
        }
      }
    }

    stage('approval') {
      when {
        expression {
          return (params.ENV == 'stage' || params.ENV == 'prod') &&
            (params.ACTION == 'apply' || params.ACTION == 'destroy')
        }
      }
      steps {
        input message: "Approve ${params.ACTION} for ${params.ENV}?"
      }
    }

    stage('apply/destroy') {
      when {
        expression {
          return params.ACTION == 'apply' || params.ACTION == 'destroy'
        }
      }
      steps {
        sh 'terraform -chdir=envs/${ENV} apply -auto-approve tfplan'
      }
    }

    stage('print outputs') {
      when {
        expression {
          return params.ACTION == 'apply'
        }
      }
      steps {
        sh 'terraform -chdir=envs/${ENV} output'
      }
    }
  }
}
