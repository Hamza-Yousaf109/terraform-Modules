pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_VERSION = '1.5.0'

        // FIX: must NOT use sh() here
        GIT_COMMIT_MSG = ''
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment (auto-detect reads from git changes)')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible playbook after Terraform')
    }

    stages {

        stage('Checkout') {
            steps {
                echo '🔄 Checking out code...'
                checkout scm
                sh 'git log --oneline -1'

                script {
                    // FIXED PLACE: sh() moved here
                    env.GIT_COMMIT_MSG = sh(
                        script: "git log -1 --format=%B",
                        returnStdout: true
                    ).trim()

                    echo "Commit Message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('Detect Environment') {
            steps {
                echo '🔍 Detecting changed environment...'
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {

                        def changedFiles = sh(
                            script: "git diff --name-only HEAD~1..HEAD 2>/dev/null || git ls-files",
                            returnStdout: true
                        ).trim()

                        if (changedFiles.contains('environments/dev')) {
                            env.DETECTED_ENV = 'dev'
                        } else if (changedFiles.contains('environments/stag')) {
                            env.DETECTED_ENV = 'stag'
                        } else if (changedFiles.contains('environments/prod')) {
                            env.DETECTED_ENV = 'prod'
                        } else {
                            env.DETECTED_ENV = 'dev'
                        }

                    } else {
                        env.DETECTED_ENV = params.ENVIRONMENT
                    }

                    echo "════════════════════════════"
                    echo "Target Environment: ${env.DETECTED_ENV}"
                    echo "════════════════════════════"
                }
            }
        }

        stage('AWS Credentials Check') {
            steps {
                echo '🔐 Configuring AWS credentials...'

                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
                        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
                        aws configure set region "$AWS_REGION"

                        aws sts get-caller-identity
                    '''
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

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
                input message: "Approve Terraform apply for ${env.DETECTED_ENV}?", ok: "YES"

                withCredentials([
                    string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
                        export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

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
                    sudo apt install ansible -y || true
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
                echo "Deployment completed for ${env.DETECTED_ENV}"
            }
        }
    }

    post {
        success {
            echo "✅ SUCCESS: ${env.DETECTED_ENV}"
        }
        failure {
            echo "❌ FAILED pipeline"
        }
    }
}