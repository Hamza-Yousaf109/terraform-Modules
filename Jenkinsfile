pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
        AWS_CREDS = '58cd422e-c62f-42b3-90fa-13626c77e829'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true, description: 'Apply Terraform')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible')
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
                echo "🔄 Code checked out"
            }
        }

        stage('Detect Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {
                        def changes = sh(script: "git diff --name-only HEAD~1..HEAD || true", returnStdout: true).trim()

                        if (changes.contains('environments/dev')) {
                            env.DETECTED_ENV = 'dev'
                        } else if (changes.contains('environments/stag')) {
                            env.DETECTED_ENV = 'stag'
                        } else if (changes.contains('environments/prod')) {
                            env.DETECTED_ENV = 'prod'
                        } else {
                            env.DETECTED_ENV = 'dev'
                        }
                    } else {
                        env.DETECTED_ENV = params.ENVIRONMENT
                    }

                    echo "🎯 Environment: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Authentication') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        echo "🔧 Terraform Init..."
                        terraform init -reconfigure -input=false

                        echo "✔ Validate..."
                        terraform validate

                        echo "📋 Plan..."
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM == true }
            }
            steps {
                input message: "Apply Terraform for ${env.DETECTED_ENV}?"

                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        terraform apply -auto-approve tfplan

                        echo "📦 Exporting Terraform output..."
                        terraform output -json > tf_output.json
                    '''
                }
            }
        }

        stage('Generate Ansible Inventory') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                sh '''
                    set -e

                    echo "🧠 Generating inventory..."

                    bash scripts/terraform_to_ansible.sh \
                        environments/${DETECTED_ENV}/tf_output.json \
                        inventory/hosts.ini

                    cat inventory/hosts.ini
                '''
            }
        }

        stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: 'ec2-key', keyFileVariable: 'SSH_KEY')
                ]) {
                    sh '''
                        set -e

                        export ANSIBLE_PRIVATE_KEY_FILE=$SSH_KEY

                        echo "🚀 Running Ansible Playbook..."

                        ansible-playbook -i inventory/hosts.ini ansible/playbook.yml -u ubuntu
                    '''
                }
            }
        }

        stage('Verify') {
            steps {
                echo "✅ Deployment completed successfully for ${env.DETECTED_ENV}"
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS: Full pipeline executed"
        }

        failure {
            echo "❌ PIPELINE FAILED - check logs"
        }
    }
}