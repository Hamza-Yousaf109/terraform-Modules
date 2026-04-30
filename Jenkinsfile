pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
        AWS_CREDS = '58cd422e-c62f-42b3-90fa-13626c77e829'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['auto-detect', 'dev', 'stag', 'prod'], description: 'Select environment')
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: true, description: 'Apply Terraform')
        booleanParam(name: 'RUN_ANSIBLE', defaultValue: true, description: 'Run Ansible Playbook')
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

                    echo "🎯 Environment: ${env.DETECTED_ENV}"
                }
            }
        }

        stage('AWS Authentication') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh "aws sts get-caller-identity"
                }
            }
        }

        stage('Terraform Init & Plan') {
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        echo "🔧 Terraform Init..."
                        terraform init -reconfigure -input=false

                        echo "✔️ Validate..."
                        terraform validate

                        echo "📋 Plan..."
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

                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        terraform apply -auto-approve tfplan

                        echo "📤 Saving terraform output..."
                        terraform output -json > tf_output.json
                    '''
                }
            }
        }

        stage('Export Terraform Output') {
            when {
                expression { params.RUN_ANSIBLE == true }
            }
            steps {
                withCredentials([aws(credentialsId: "${AWS_CREDS}")]) {
                    sh '''
                        set -e
                        cd environments/${DETECTED_ENV}

                        echo "📦 Exporting Terraform output..."
                        terraform output -json > tf_output.json

                        echo "📋 Output Preview:"
                        cat tf_output.json | jq .
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
                    set -e

                    echo "🧠 Generating inventory..."

                    bash scripts/terraform_to_ansible.sh \
                        environments/${DETECTED_ENV}/tf_output.json \
                        inventory/hosts.ini

                    echo "📄 Inventory:"
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
                    set -e

                    HOST_COUNT=$(awk '
                        BEGIN {count=0; in_group=0}
                        /^\\[jenkins_servers\\]/ {in_group=1; next}
                        /^\\[/ {in_group=0}
                        in_group && /^[^#[:space:]]/ {count++}
                        END {print count+0}
                    ' inventory/hosts.ini)

                    if [ "$HOST_COUNT" -eq 0 ]; then
                        echo "❌ No hosts found in inventory"
                        exit 1
                    fi

                    echo "🚀 Running Ansible..."
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
            echo "🎉 SUCCESS: Pipeline completed"
        }
        failure {
            echo "❌ PIPELINE FAILED - Check logs"
        }
    }
}