pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select Environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform Changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible after deploy')
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm

                script {
                    env.COMMIT_MSG = sh(script: "git log -1 --format=%B", returnStdout: true).trim()
                    echo "Commit: ${env.COMMIT_MSG}"
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

                    echo "🎯 Environment: ${env.DETECTED_ENV}"
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

        stage('Terraform Init & Plan') {
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
                input message: "Apply Terraform for ${env.DETECTED_ENV}?"

                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }

        stage('Generate Terraform Output File') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }

            steps {
                withCredentials([aws(credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829')]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        terraform output -json > /tmp/tf_output.json
                        echo "Terraform output saved"
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
                    echo "🧠 Generating Inventory..."
                    python3 scripts/terraform_to_ansible.py environments/${DETECTED_ENV} inventory/hosts.ini
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
                    echo "🚀 Running Ansible..."
                    ansible-playbook -i inventory/hosts.ini ansible/playbook.yml
                '''
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
            echo "🎉 SUCCESS: ${env.DETECTED_ENV} pipeline completed"
        }

        failure {
            echo "❌ PIPELINE FAILED"
        }
    }
}