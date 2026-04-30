pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
        TF_DIR = "environments"
        INVENTORY_FILE = "inventory/hosts.ini"
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform changes')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible Playbook')
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

                        if (changes.contains('prod')) {
                            env.DETECTED_ENV = 'prod'
                        } else if (changes.contains('stag')) {
                            env.DETECTED_ENV = 'stag'
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

        stage('AWS Authentication') {
            steps {
                script {
                    try {
                        withCredentials([aws(credentialsId: 'aws-creds')]) {
                            sh "aws sts get-caller-identity"
                        }
                    } catch (err) {
                        echo "⚠️ AWS credentials not found, but continuing pipeline..."
                    }
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-creds')]) {
                        sh """
                            set -e
                            cd ${TF_DIR}/${DETECTED_ENV}

                            echo "🔧 Initializing Terraform..."
                            terraform init -reconfigure -input=false
                            
                            echo "✔️ Validating configuration..."
                            terraform validate
                            
                            echo "📋 Running terraform plan..."
                            terraform plan -out=tfplan
                            
                            echo "📊 Checking available outputs..."
                            terraform output -json | jq 'keys' || true
                        """
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { params.APPLY_TERRAFORM == true }
            }
            steps {
                input message: "Apply Terraform for ${env.DETECTED_ENV}?"
                script {
                    withCredentials([aws(credentialsId: 'aws-creds')]) {
                        sh """
                            cd ${TF_DIR}/${DETECTED_ENV}
                            terraform apply -auto-approve tfplan
                        """
                    }
                }
            }
        }

        stage('Export Terraform Output') {
            when {
                expression { params.RUN_ANSIBLE == true && params.APPLY_TERRAFORM == true }
            }
            steps {
                script {
                    sh """
                        set -e
                        cd ${TF_DIR}/${DETECTED_ENV}

                        terraform output -json > ../../tf_output.json || echo "{}" > ../../tf_output.json

                        echo "📦 Terraform output saved"
                        echo "📋 Output content:"
                        cat ../../tf_output.json | jq . || cat ../../tf_output.json
                    """
                }
            }
        }

        stage('Generate Ansible Inventory') {
            when {
                expression { params.RUN_ANSIBLE == true && params.APPLY_TERRAFORM == true }
            }
            steps {
                script {
                    sh """
                        set -e
                        echo "🧠 Generating inventory..."

                        chmod +x scripts/terraform_to_ansible.sh
                        
                        # Debug: Show what we're passing to the script
                        echo "Input file content:"
                        jq . tf_output.json 2>/dev/null || cat tf_output.json
                        
                        bash scripts/terraform_to_ansible.sh \
                            tf_output.json \
                            ${INVENTORY_FILE}

                        echo ""
                        echo "Generated inventory:"
                        cat ${INVENTORY_FILE}
                    """
                }
            }
        }

                stage('Run Ansible Playbook') {
            when {
                expression { params.RUN_ANSIBLE == true && params.APPLY_TERRAFORM == true }
            }
            steps {
                script {
                    sh """
                        set -e
                        
                        # Count hosts under the jenkins_servers group
                        HOST_COUNT=\$(awk 'BEGIN {count=0; in_group=0} /^\\[jenkins_servers\\]/ {in_group=1; next} /^\\[/ {in_group=0} in_group && /^[^#[:space:]]/ {count++} END {print count+0}' \${INVENTORY_FILE} 2>/dev/null)
                        HOST_COUNT=\${HOST_COUNT:-0}
                        
                        if [ "\${HOST_COUNT}" = "" ] || [ "\${HOST_COUNT}" -eq 0 ]; then
                            echo "WARNING: No instances found in inventory"
                            echo "Make sure EC2 instances were created successfully"
                            echo "Inventory content:"
                            cat \${INVENTORY_FILE}
                            exit 1
                        fi
                        
                        echo "Running Ansible on \${HOST_COUNT} host(s)..."
                        ansible-playbook -i \${INVENTORY_FILE} ansible/playbook.yml
                    """
                }
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
            echo "🎉 SUCCESS pipeline finished"
        }
        failure {
            echo "❌ Pipeline failed - check logs"
        }
    }
}