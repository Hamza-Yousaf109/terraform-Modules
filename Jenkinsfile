pipeline {
    agent any

    environment {
        AWS_REGION = 'ca-central-1'
        TF_IN_AUTOMATION = 'true'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible playbook')
    }

    stages {

        stage('Checkout') {
            steps {
                echo "🔄 Cloning repository..."
                checkout scm

                script {
                    env.GIT_MSG = sh(script: "git log -1 --format=%B", returnStdout: true).trim()
                    echo "Commit Message: ${env.GIT_MSG}"
                }
            }
        }

        stage('Detect Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {

                        def changes = sh(script: "git diff --name-only HEAD~1..HEAD || true", returnStdout: true).trim()

                        if (changes.contains('environments/dev')) {
                            env.TARGET_ENV = 'dev'
                        } else if (changes.contains('environments/stag')) {
                            env.TARGET_ENV = 'stag'
                        } else if (changes.contains('environments/prod')) {
                            env.TARGET_ENV = 'prod'
                        } else {
                            env.TARGET_ENV = 'dev'
                        }

                    } else {
                        env.TARGET_ENV = params.ENVIRONMENT
                    }

                    echo "🎯 Target Environment: ${env.TARGET_ENV}"
                }
            }
        }

        stage('AWS Credentials Check') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829'
                ]]) {
                    sh 'aws sts get-caller-identity'
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829'
                ]]) {
                    sh '''
                        set -e
                        cd environments/${TARGET_ENV}

                        echo "🚀 Terraform Init"
                        terraform init -reconfigure -input=false

                        echo "🔍 Validate"
                        terraform validate

                        echo "📦 Plan"
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
                input message: "Apply Terraform for ${env.TARGET_ENV}?", ok: "YES"

                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829'
                ]]) {
                    sh '''
                        set -e
                        cd environments/${TARGET_ENV}

                        terraform apply -auto-approve tfplan
                        terraform output -json > outputs.json
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
                    python3 scripts/terraform_to_ansible.py \
                        environments/${TARGET_ENV} \
                        ansible/inventory.ini
                '''
            }
        }

        stage('Install Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                sh '''
                    sudo apt update -y
                    sudo apt install -y ansible
                    ansible --version
                '''
            }
        }

        stage('SSH Setup') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                withCredentials([file(credentialsId: 'devops-ssh-key', variable: 'SSH_KEY')]) {
                    sh '''
                        mkdir -p ~/.ssh
                        cp $SSH_KEY ~/.ssh/id_rsa
                        chmod 600 ~/.ssh/id_rsa

                        HOST=$(grep ansible_host ansible/inventory.ini | head -1 | awk '{print $NF}' | cut -d'=' -f2)

                        ssh-keyscan -H $HOST >> ~/.ssh/known_hosts
                    '''
                }
            }
        }

        stage('Run Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                sh '''
                    ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/playbook.yml \
                        -u ubuntu \
                        --private-key=~/.ssh/id_rsa
                '''
            }
        }

        stage('Verify') {
            steps {
                echo "✅ Deployment completed for ${env.TARGET_ENV}"
            }
        }
    }

    post {
        success {
            echo "🎉 SUCCESS: ${env.TARGET_ENV} deployment completed"
        }

        failure {
            echo "❌ FAILED pipeline - check logs"
        }
    }
}