pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_DIR = "environments/dev"
        INVENTORY_FILE = "inventory/hosts.ini"
        TF_OUTPUT_FILE = "tf_output.json"
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'])
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true)
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true)
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
                    env.DETECTED_ENV = (params.ENVIRONMENT == 'auto-detect') ? 'dev' : params.ENVIRONMENT
                    env.TF_DIR = "environments/${env.DETECTED_ENV}"
                    echo "🎯 ENV: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Auth Check') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init / Plan') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh '''
                        set -e
                        cd $TF_DIR
                        terraform init -reconfigure
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
                input message: "Apply Terraform?"
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh '''
                        cd $TF_DIR
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Export Terraform Output') {
            steps {
                withCredentials([aws(credentialsId: 'aws-creds')]) {
                    sh '''
                        cd $TF_DIR
                        terraform output -json > ../../$TF_OUTPUT_FILE
                        cat ../../$TF_OUTPUT_FILE
                    '''
                }
            }
        }

        stage('Generate Ansible Inventory') {
            steps {
                sh '''
                    python3 scripts/terraform_to_ansible.py tf_output.json inventory/hosts.ini
                    cat inventory/hosts.ini
                '''
            }
        }

        stage('Run Ansible') {
            when {
                expression { params.RUN_ANSIBLE }
            }
            steps {
                sh '''
                    ansible-playbook -i inventory/hosts.ini ansible/playbook.yml
                '''
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS: ${env.DETECTED_ENV} deployed"
        }
        failure {
            echo "❌ PIPELINE FAILED"
        }
    }
}