pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible playbook')
    }

    stages {

        stage('Checkout') {
            steps {
                echo "🔄 Checkout code"
                checkout scm

                script {
                    env.GIT_COMMIT_MSG = sh(
                        script: "git log -1 --format=%B || echo 'no commit'",
                        returnStdout: true
                    ).trim()

                    echo "Commit: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('Detect Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {

                        def changes = sh(
                            script: "git diff --name-only HEAD~1..HEAD || true",
                            returnStdout: true
                        ).trim()

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

                    echo "Target Environment: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Auth Check') {
            steps {
                echo "🔐 Checking AWS credentials"

                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829'
                ]]) {
                    sh '''
                        aws sts get-caller-identity
                    '''
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
                        cd environments/${DETECTED_ENV}

                        terraform init
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
                input message: "Apply Terraform for ${env.DETECTED_ENV}?", ok: "YES"

                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: '58cd422e-c62f-42b3-90fa-13626c77e829'
                ]]) {
                    sh '''
                        cd environments/${DETECTED_ENV}

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
                        environments/${DETECTED_ENV} \
                        ansible/inventory.ini

                    cat ansible/inventory.ini
                '''
            }
        }

        stage('Setup Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                sh '''
                    sudo apt update -y || true
                    sudo apt install -y ansible || true
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
                        cp $SSH_KEY ~/.ssh/key.pem
                        chmod 600 ~/.ssh/key.pem

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
                        --private-key=~/.ssh/key.pem
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
            echo "🎉 SUCCESS: ${env.DETECTED_ENV}"
        }
        failure {
            echo "❌ FAILED pipeline"
        }
    }
}