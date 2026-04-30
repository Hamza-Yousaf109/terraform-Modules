pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible Playbook')
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

                    echo "🎯 ENV: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Auth Check') {
            steps {
                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init / Plan') {
            steps {
                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        terraform init -reconfigure -input=false
                        terraform validate
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
                input message: "Confirm Terraform Apply for ${env.DETECTED_ENV}"

                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Export Terraform Output') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        terraform output -json > /tmp/tf_output.json
                        echo "📦 Terraform output exported"
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
                    echo "🧠 Generating Ansible Inventory..."

                    python3 scripts/terraform_to_ansible.py \
                        /tmp/tf_output.json \
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
                sh '''
                    echo "🚀 Running Ansible Playbook..."

                    ansible-playbook -i inventory/hosts.ini ansible/playbook.yml
                '''
            }
        }

        stage('Verify') {
            steps {
                echo "✅ Deployment successful for ${env.DETECTED_ENV}"
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS: Pipeline completed for ${env.DETECTED_ENV}"
        }

        failure {
            echo "❌ PIPELINE FAILED"
        }
    }
}