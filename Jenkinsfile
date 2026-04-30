pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_VERSION = '1.5.0'
        GIT_COMMIT_MSG = sh(script: "git log -1 --format=%B", returnStdout: true).trim()
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
            }
        }
        
        stage('Detect Environment') {
            steps {
                echo '🔍 Detecting changed environment...'
                script {
                    if (params.ENVIRONMENT == 'auto-detect') {
                        // Detect which environment changed
                        def changedFiles = sh(script: "git diff --name-only HEAD~1..HEAD 2>/dev/null || git ls-files", returnStdout: true).trim()
                        
                        if (changedFiles.contains('environments/dev')) {
                            env.DETECTED_ENV = 'dev'
                            echo "✓ Auto-detected changes in: dev"
                        } else if (changedFiles.contains('environments/stag')) {
                            env.DETECTED_ENV = 'stag'
                            echo "✓ Auto-detected changes in: stag"
                        } else if (changedFiles.contains('environments/prod')) {
                            env.DETECTED_ENV = 'prod'
                            echo "✓ Auto-detected changes in: prod"
                        } else {
                            env.DETECTED_ENV = 'dev'
                            echo "⚠️ No environment changes detected, defaulting to: dev"
                        }
                    } else {
                        env.DETECTED_ENV = params.ENVIRONMENT
                        echo "✓ Using specified environment: ${params.ENVIRONMENT}"
                    }
                    
                    echo "═══════════════════════════════════════════"
                    echo "Target Environment: ${env.DETECTED_ENV}"
                    echo "═══════════════════════════════════════════"
                }
            }
        }
        
        stage('AWS Credentials Check') {
            steps {
                echo '🔐 Configuring AWS credentials...'
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        # Verify AWS credentials are set
                        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                            echo "❌ AWS credentials not found in Jenkins secrets!"
                            echo "Please add Jenkins credentials:"
                            echo "  - aws-access-key-id (Secret text)"
                            echo "  - aws-secret-access-key (Secret text)"
                            exit 1
                        fi
                        
                        # Configure AWS CLI with credentials
                        aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
                        aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
                        aws configure set region "$AWS_REGION"
                        
                        # Test AWS credentials
                        echo "✓ Testing AWS credentials..."
                        aws sts get-caller-identity
                        echo "✓ AWS credentials configured successfully"
                    '''
                }
            }
        }
        
        stage('Terraform Validate') {
            steps {
                echo '✓ Validating Terraform...'
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
                        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
                        
                        echo "Working in: environments/${DETECTED_ENV}"
                        cd "environments/${DETECTED_ENV}"
                        
                        terraform init
                        terraform validate
                        terraform plan -out=tfplan
                        
                        echo "✓ Terraform validation successful"
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM == true }
            }
            steps {
                script {
                    // Require approval for all environments (dev, stag, prod)
                    def userApproval = input(
                        id: 'ApproveDeployment',
                        message: """
                            ⚠️  DEPLOYMENT APPROVAL REQUIRED ⚠️
                            
                            Environment: ${env.DETECTED_ENV.toUpperCase()}
                            
                            This will apply Terraform changes to: ${env.DETECTED_ENV}
                            
                            📋 ACTION REQUIRED:
                            1. Review the Terraform plan output above
                            2. Verify all changes are correct
                            3. Confirm this is the right environment
                            4. Click [APPROVE & APPLY] to proceed
                            
                            ⏹️  Click [ABORT] to cancel deployment
                        """,
                        ok: 'APPROVE & APPLY',
                        submitter: 'developers,admin'
                    )
                    echo "✅ Deployment approved by: ${userApproval}"
                }
                
                echo '🚀 Applying Terraform to ${DETECTED_ENV}...'
                withCredentials([string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
                        export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
                        
                        cd "environments/${DETECTED_ENV}"
                        
                        echo "═══════════════════════════════════════════"
                        echo "Applying Terraform to: ${DETECTED_ENV}"
                        echo "═══════════════════════════════════════════"
                        
                        terraform apply -auto-approve tfplan
                        terraform output -json > outputs.json
                        
                        echo "✓ Terraform apply completed for ${DETECTED_ENV}"
                    '''
                }
                archiveArtifacts artifacts: "environments/${DETECTED_ENV}/outputs.json", allowEmptyArchive: true
            }
        }
        
        stage('Generate Ansible Inventory') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '📝 Generating Ansible inventory from Terraform outputs...'
                sh '''
                    echo "Generating inventory for: ${DETECTED_ENV}"
                    python3 scripts/terraform_to_ansible.py \
                        "environments/${DETECTED_ENV}" \
                        "ansible/inventory_${DETECTED_ENV}.ini"
                    
                    # Copy to main inventory for Ansible
                    cp "ansible/inventory_${DETECTED_ENV}.ini" ansible/inventory.ini
                    
                    echo "✓ Generated inventory:"
                    cat ansible/inventory.ini
                '''
            }
        }
        
        stage('Setup Ansible') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '⚙️ Setting up Ansible...'
                sh '''
                    apt-get update -y 2>/dev/null || true
                    apt-get install -y ansible 2>/dev/null || true
                    ansible --version
                    echo "✓ Ansible installed"
                '''
            }
        }
        
        stage('Configure SSH Access') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '🔐 Configuring SSH access for ${DETECTED_ENV}...'
                withCredentials([file(credentialsId: 'devops-ssh-key', variable: 'SSH_KEY')]) {
                    sh '''
                        mkdir -p ~/.ssh
                        cp $SSH_KEY ~/.ssh/devops.pem
                        chmod 600 ~/.ssh/devops.pem
                        
                        # Get EC2 IP from inventory
                        JENKINS_HOST=$(grep "ansible_host" ansible/inventory.ini | awk '{print $NF}' | cut -d'=' -f2 | head -1)
                        
                        echo "Adding EC2 host to known_hosts: $JENKINS_HOST"
                        ssh-keyscan -H "$JENKINS_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true
                        
                        echo "✓ SSH access configured"
                    '''
                }
            }
        }
        
        stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '📦 Running Ansible playbook to configure Jenkins on ${DETECTED_ENV}...'
                sh '''
                    echo "═══════════════════════════════════════════"
                    echo "Configuring Jenkins on: ${DETECTED_ENV}"
                    echo "═══════════════════════════════════════════"
                    
                    ansible-playbook \
                        -i ansible/inventory.ini \
                        ansible/playbook.yml \
                        -v \
                        -u ubuntu \
                        --private-key=~/.ssh/devops.pem
                    
                    echo "✓ Ansible playbook completed"
                '''
            }
        }
        
        stage('Verify Jenkins Installation') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                echo '✅ Verifying Jenkins installation on ${DETECTED_ENV}...'
                sh '''
                    JENKINS_HOST=$(grep "ansible_host" ansible/inventory.ini | awk '{print $NF}' | cut -d'=' -f2 | head -1)
                    
                    echo "═══════════════════════════════════════════"
                    echo "Jenkins Installation Summary"
                    echo "═══════════════════════════════════════════"
                    echo "Environment: ${DETECTED_ENV}"
                    echo "Jenkins URL: http://$JENKINS_HOST:8080"
                    echo ""
                    echo "To get the initial admin password, run:"
                    echo "  ssh -i ~/.ssh/devops.pem ubuntu@$JENKINS_HOST"
                    echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
                    echo ""
                    
                    # Wait for Jenkins to start
                    echo "Waiting for Jenkins to start (30 seconds)..."
                    sleep 30
                    
                    # Try to access Jenkins
                    if curl -s -o /dev/null -w "%{http_code}" http://$JENKINS_HOST:8080 | grep -q "200\|403"; then
                        echo "✓ Jenkins is running!"
                    else
                        echo "⚠️ Jenkins may still be starting up..."
                    fi
                    
                    echo "═══════════════════════════════════════════"
                '''
            }
        }
    }
    
    post {
        success {
            echo "✓ Pipeline completed successfully for ${DETECTED_ENV}!"
            archiveArtifacts artifacts: "ansible/inventory_${DETECTED_ENV}.ini", allowEmptyArchive: true
        }
        failure {
            echo "✗ Pipeline failed. Check logs above for ${DETECTED_ENV}."
        }
        always {
            sh '''
                # Keep important files, clean up rest
                echo "Cleaning up temporary files..."
                # Note: Not using cleanWs() to preserve outputs
            '''
        }
    }
}
