pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'

        // 🔥 IMPORTANT: single source of truth for credentials
        AWS_CREDS_ID = 'aws-creds'

        TF_DIR = ""
        TF_OUTPUT_FILE = "/tmp/tf_output.json"
        INVENTORY_FILE = "inventory/hosts.ini"
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true, description: 'Apply Terraform')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible Playbook')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "🔄 Repository checked out"
            }
        }

        stage('Detect Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {
                        def changes = sh(script: "git diff --name-only HEAD~1..HEAD || true", returnStdout: true).trim()

                        if (changes.contains('environments/prod')) {
                            env.DETECTED_ENV = 'prod'
                        } else if (changes.contains('environments/stag')) {
                            env.DETECTED_ENV = 'stag'
                        } else {
                            env.DETECTED_ENV = 'dev'
                        }
                    } else {
                        env.DETECTED_ENV = params.ENVIRONMENT
                    }

                    env.TF_DIR = "environments/${env.DETECTED_ENV}"

                    echo "🎯 Selected Environment: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Authentication') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS_ID}")]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS_ID}")]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        terraform init -reconfigure -input=false
                        terraform validate
                        terraform plan -out=tfplan
                    '''
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM }
            }
            steps {
                input message: "Confirm Terraform Apply for ${env.DETECTED_ENV}"

                withCredentials([aws(credentialsId: "${AWS_CREDS_ID}")]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Export Terraform Output') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS_ID}")]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        terraform output -json > $TF_OUTPUT_FILE

                        echo "📦 Terraform output generated"
                        cat $TF_OUTPUT_FILE
                    '''
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                sh '''
                    echo "🧠 Generating inventory..."

                    python3 scripts/terraform_to_ansible.py \
                        $TF_OUTPUT_FILE \
                        $INVENTORY_FILE

                    echo "📄 Inventory file:"
                    cat $INVENTORY_FILE
                '''
            }
        }

        stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE }
            }
            steps {
                sh '''
                    echo "🚀 Running Ansible Playbook..."

                    ansible-playbook -i $INVENTORY_FILE ansible/playbook.yml
                '''
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
            echo "🎉 SUCCESS: ${env.DETECTED_ENV} pipeline completed"
        }

        failure {
            echo "❌ PIPELINE FAILED - check logs"
        }
    }
}