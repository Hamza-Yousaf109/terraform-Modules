pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_VERSION = '1.5.0'
        ENVIRONMENT = 'dev'
    }
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: false, description: 'Run Ansible playbook')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '🔄 Checking out code...'
                checkout scm
                sh 'git log --oneline -1'
            }
        }
        
        stage('Terraform Validate') {
            steps {
                echo '✓ Validating Terraform...'
                dir("environments/${params.ENVIRONMENT}") {
                    sh '''
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
                echo '🚀 Applying Terraform...'
                dir("environments/${params.ENVIRONMENT}") {
                    sh '''
                        terraform apply -auto-approve tfplan
                        terraform output -json > outputs.json
                    '''
                }
                archiveArtifacts artifacts: "environments/${params.ENVIRONMENT}/outputs.json", allowEmptyArchive: true
            }
        }
        
        stage('Generate Ansible Inventory') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '📝 Generating Ansible inventory from Terraform outputs...'
                sh '''
                    python3 scripts/terraform_to_ansible.py \
                        environments/${ENVIRONMENT} \
                        ansible/inventory.ini
                '''
                sh 'cat ansible/inventory.ini'
            }
        }
        
        stage('Setup Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '⚙️ Setting up Ansible...'
                sh '''
                    apt-get update -y
                    apt-get install -y ansible
                    ansible --version
                '''
            }
        }
        
        stage('Configure SSH Access') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '🔐 Configuring SSH access...'
                withCredentials([file(credentialsId: 'devops-ssh-key', variable: 'SSH_KEY')]) {
                    sh '''
                        mkdir -p ~/.ssh
                        cp $SSH_KEY ~/.ssh/devops.pem
                        chmod 600 ~/.ssh/devops.pem
                        
                        # Add EC2 hosts to known_hosts
                        grep ansible_host ansible/inventory.ini | awk '{print $NF}' | cut -d'=' -f2 | while read host; do
                            ssh-keyscan -H "$host" >> ~/.ssh/known_hosts 2>/dev/null || true
                        done
                    '''
                }
            }
        }
        
        stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '📦 Running Ansible playbook to configure Jenkins...'
                sh '''
                    ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/playbook.yml \
                        -v \
                        -u ubuntu \
                        --private-key=~/.ssh/devops.pem
                '''
            }
        }
        
        stage('Verify Jenkins Installation') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '✅ Verifying Jenkins installation...'
                sh '''
                    JENKINS_HOST=$(grep ansible_host ansible/inventory.ini | head -1 | awk '{print $NF}' | cut -d'=' -f2)
                    echo "Jenkins URL: http://$JENKINS_HOST:8080"
                    sleep 10
                    curl -s http://$JENKINS_HOST:8080 | head -20 || echo "Jenkins is starting..."
                '''
            }
        }
    }
    
    post {
        success {
            echo '✓ Pipeline completed successfully!'
            archiveArtifacts artifacts: 'ansible/inventory.ini', allowEmptyArchive: true
        }
        failure {
            echo '✗ Pipeline failed. Check logs above.'
        }
        always {
            cleanWs()
        }
    }
}
