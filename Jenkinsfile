pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
        TF_DIR = "environments"
        INVENTORY_FILE = "inventory/hosts.ini"
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible Playbook')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    echo "🔄 Repo checked out"
                }
            }
        }

        stage('Detect Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {
                        def changes = sh(script: "git diff --name-only HEAD~1..HEAD || true", returnStdout: true).trim()

                        if (changes.contains('prod')) {
                            env.DETECTED_ENV = 'prod'
                        } else if (changes.contains('stag')) {
                            env.DETECTED_ENV = 'stag'
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
                script {
                    try {
                        withCredentials([aws(credentialsId: 'aws-creds')]) {
                            sh "aws sts get-caller-identity"
                        }
                    } catch (err) {
                        echo "⚠️ AWS credentials not found, but continuing pipeline..."
                    }
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-creds', optional: true)]) {
                        sh """
                            set -e
                            cd ${TF_DIR}/${DETECTED_ENV}

                            terraform init -reconfigure -input=false
                            terraform validate
                            terraform plan -out=tfplan
                        """
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM == true }
            }
            steps {
                input message: "Apply Terraform for ${env.DETECTED_ENV}?"
                script {
                    withCredentials([aws(credentialsId: 'aws-creds', optional: true)]) {
                        sh """
                            cd ${TF_DIR}/${DETECTED_ENV}
                            terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        stage('Export Terraform Output') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                script {
                    sh """
                        set -e
                        cd ${TF_DIR}/${DETECTED_ENV}

                        terraform output -json > ../../tf_output.json || echo "{}" > ../../tf_output.json

                        echo "📦 Terraform output saved"
                    """
                }
            }
        }

        stage('Generate Ansible Inventory') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                script {
                    sh """
                        echo "🧠 Generating inventory..."

                        python3 scripts/terraform_to_ansible.py \
                            tf_output.json \
                            ${INVENTORY_FILE}

                        cat ${INVENTORY_FILE}
                    """
                }
            }
        }

        stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                script {
                    sh """
                        echo "🚀 Running Ansible..."

                        ansible-playbook -i ${INVENTORY_FILE} ansible/playbook.yml
                    """
                }
            }
        }

        stage('Verify') {
            steps {
                echo "✅ Deployment completed for ${env.DETECTED_ENV}"
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS pipeline finished"
        }
        failure {
            echo "❌ Pipeline failed - check logs"
        }
    }
}