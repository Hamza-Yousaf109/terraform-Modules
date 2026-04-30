pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_DIR = "environments/dev"
        INVENTORY_FILE = "inventory/hosts.ini"
        TF_OUTPUT_FILE = "tf_output.json"
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible playbook')
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "🔄 Repo checked out"
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

                    env.TF_DIR = "environments/${env.DETECTED_ENV}"
                    echo "🎯 Environment: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Auth') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init/Plan/Apply') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        terraform init -reconfigure -input=false
                        terraform validate
                        terraform plan -out=tfplan
                    '''
                }

                script {
                    if (params.APPLY_TERRAFORM) {
                        input message: "Apply Terraform for ${env.DETECTED_ENV}?"

                        withCredentials([aws(credentialsId: 'aws-creds')]) {
                            sh '''
                                set -e
                                cd $TF_DIR
                                terraform apply -auto-approve tfplan
                            '''
                        }
                    }
                }
            }
        }

        stage('Export Terraform Output (FIXED)') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh '''
                        set -e
                        cd $TF_DIR

                        terraform output -json > ../../$TF_OUTPUT_FILE

                        echo "📦 Terraform output saved to file"
                        cat ../../$TF_OUTPUT_FILE
                    '''
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                sh '''
                    echo "🧠 Generating Inventory..."
                    python3 scripts/terraform_to_ansible.py $TF_OUTPUT_FILE $INVENTORY_FILE

                    echo "📄 Inventory:"
                    cat $INVENTORY_FILE
                '''
            }
        }

        stage('Run Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                sh '''
                    echo "🚀 Running Ansible..."
                    ansible-playbook -i $INVENTORY_FILE ansible/playbook.yml
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS: ${env.DETECTED_ENV} deployed"
        }
        failure {
            echo "❌ FAILED pipeline"
        }
    }
}