# Automated DevOps Pipeline: Terraform → Ansible → Jenkins

## 📋 Overview
This project automates the complete infrastructure and Jenkins setup workflow:
1. **Terraform** provisions EC2 instances on AWS
2. **Python script** (glue code) converts Terraform outputs to Ansible inventory
3. **Ansible** connects to EC2 and automatically installs & configures Jenkins
4. **Jenkins** pipeline orchestrates the entire process

---

## 📁 Project Structure

```
.
├── ansible/
│   ├── inventory.ini          # Ansible hosts (auto-generated)
│   └── playbook.yml           # Jenkins installation playbook
├── environments/
│   ├── dev/
│   │   ├── provider.tf        # AWS provider config
│   │   ├── apply.tf           # Dev environment resources
│   │   └── backend.tf         # Terraform state backend
│   └── stag/                  # Staging environment (similar)
├── module/
│   ├── ec2/                   # EC2 module
│   │   ├── main.tf
│   │   ├── variable.tf
│   │   └── outputs.tf         # ✨ Enhanced with Ansible-friendly outputs
│   ├── vpc/                   # VPC module
│   └── s3/                    # S3 module
├── scripts/
│   └── terraform_to_ansible.py  # 🔗 Glue script: Terraform → Ansible
├── .github/
│   └── workflows/
│       └── pipeline.yaml      # GitHub Actions CI/CD workflow
└── Jenkinsfile                # Jenkins pipeline definition
```

---

## 🚀 Prerequisites

### 1. AWS Setup
- AWS Account with access keys
- EC2 Key Pair named `devops` (configure in `environments/dev/apply.tf`)

### 2. GitHub Setup (for GitHub Actions)
Add these secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
- `SSH_PRIVATE_KEY` - Content of your `devops.pem` file

### 3. Jenkins Setup (for Jenkins Pipeline)
Jenkins server needs:
- Terraform installed
- Python 3 installed
- Git plugin
- SSH key pair stored in Jenkins credentials as `devops-ssh-key`

### 4. Local Machine
```bash
# Install Terraform
# Install Ansible
# Install AWS CLI
# Configure AWS credentials
aws configure
```

---

## 🔧 How It Works

### Phase 1: Terraform Provisioning
```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

**What happens:**
- EC2 instance created with Ubuntu 22.04
- VPC and subnet configured
- Security group created
- Instance details output in structured format

### Phase 2: Generate Ansible Inventory (Glue Script)
```bash
python3 scripts/terraform_to_ansible.py \
    environments/dev \
    ansible/inventory.ini
```

**What the script does:**
- Reads `terraform output -json`
- Extracts instance IPs and details
- Creates `ansible/inventory.ini` dynamically
- No manual inventory editing needed! ✅

### Phase 3: Run Ansible Playbook
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

**What happens:**
- SSH to EC2 instance
- Install Java (OpenJDK 11)
- Add Jenkins repository
- Install Jenkins
- Start Jenkins service
- Display Jenkins URL and initial password

---

## 📜 Example Workflow

### Using GitHub Actions (Auto-triggered on push)
1. Push code to repository
2. GitHub Actions detects changes in `environments/dev/`
3. Runs Terraform plan and apply
4. Generates Ansible inventory
5. Runs Ansible playbook
6. Jenkins is now running on EC2! 🎉

### Using Jenkins Pipeline
1. Create new Jenkins job and point to `Jenkinsfile`
2. Configure Jenkins credentials (SSH key as `devops-ssh-key`)
3. Run the job with parameters:
   - Environment: `dev`
   - Apply Terraform: ✓
   - Run Ansible: ✓
4. Jenkins configures itself on EC2! 🎉

---

## 📝 Configuration Files

### Terraform Outputs (`module/ec2/outputs.tf`)
Key output: `instances_with_ssh` provides:
```json
{
  "instances": [
    {
      "name": "test-1",
      "ansible_host": "54.123.45.67",
      "ansible_user": "ubuntu",
      "private_ip": "10.0.0.1",
      "instance_id": "i-xxxxx",
      "availability_zone": "us-east-1a"
    }
  ]
}
```

### Glue Script (`scripts/terraform_to_ansible.py`)
- Reads Terraform JSON output
- Parses instance details
- Generates INI-format inventory for Ansible
- Handles SSH connection details

### Ansible Playbook (`ansible/playbook.yml`)
Tasks:
1. Install OpenJDK 11
2. Add Jenkins repository
3. Install Jenkins package
4. Start and enable Jenkins service
5. Display Jenkins URL and password

---

## 🎯 Running Locally (Step-by-Step)

### Step 1: Initialize and Apply Terraform
```bash
cd environments/dev
terraform init
terraform apply
```

### Step 2: Generate Ansible Inventory
```bash
cd ../../
python3 scripts/terraform_to_ansible.py environments/dev ansible/inventory.ini
cat ansible/inventory.ini  # Verify it generated correctly
```

### Step 3: Configure SSH
```bash
mkdir -p ~/.ssh
# Place your devops.pem file in ~/.ssh/
chmod 600 ~/.ssh/devops.pem
```

### Step 4: Run Ansible
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -v
```

### Step 5: Access Jenkins
Once the playbook completes:
```
Jenkins URL: http://<EC2-PUBLIC-IP>:8080
```

To get the initial admin password:
```bash
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-PUBLIC-IP>
cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## 🐛 Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connection
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "whoami"

# Add host to known_hosts
ssh-keyscan -H <EC2-IP> >> ~/.ssh/known_hosts
```

### Ansible Inventory Not Generated
```bash
# Check if terraform outputs exist
cd environments/dev
terraform output -json

# Check script output
python3 scripts/terraform_to_ansible.py environments/dev ansible/inventory.ini -v
```

### Jenkins Not Starting
```bash
# SSH to instance and check logs
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP>
sudo systemctl status jenkins
sudo tail -100 /var/log/jenkins/jenkins.log
```

### Port 8080 Not Accessible
```bash
# Check security group allows inbound on 8080
aws ec2 describe-security-groups --group-ids <SG-ID>

# Add rule if missing (modify security group in Terraform)
```

---

## 🔐 Security Best Practices

1. **SSH Keys**
   - Never commit private keys to Git
   - Use `.gitignore` to exclude `.pem` files
   - Store SSH keys in Jenkins credentials or GitHub secrets

2. **Security Group Rules**
   - Restrict SSH access (not 0.0.0.0/0 in production)
   - Limit Jenkins UI access (8080) to trusted IPs
   - Use VPN/bastion host for production

3. **AWS Credentials**
   - Use IAM roles instead of access keys (when possible)
   - Rotate credentials regularly
   - Never commit credentials to Git

---

## 📚 File Reference

| File | Purpose |
|------|---------|
| `Jenkinsfile` | Jenkins pipeline definition |
| `scripts/terraform_to_ansible.py` | Glue script: Terraform → Ansible |
| `ansible/inventory.ini` | Ansible hosts (auto-generated) |
| `ansible/playbook.yml` | Jenkins installation playbook |
| `module/ec2/outputs.tf` | Terraform outputs for Ansible |
| `.github/workflows/pipeline.yaml` | GitHub Actions workflow |

---

## ✅ Verification Checklist

- [ ] Terraform provisions EC2 successfully
- [ ] Glue script generates `ansible/inventory.ini` without errors
- [ ] Ansible can SSH to EC2 instance
- [ ] Ansible playbook completes without errors
- [ ] Jenkins service is running on EC2
- [ ] Jenkins UI accessible at `http://<EC2-IP>:8080`
- [ ] GitHub Actions or Jenkins pipeline executes automatically

---

## 🎓 Student Notes
This pipeline demonstrates:
- **Infrastructure as Code** (Terraform)
- **Configuration Management** (Ansible)
- **CI/CD Automation** (GitHub Actions & Jenkins)
- **Scripting & Integration** (Python glue code)
- **Cloud AWS** (EC2, VPC, Security Groups)

Perfect for learning DevOps fundamentals!

---

## 📞 Support
For issues or questions, check:
1. Terraform logs: `terraform.log`
2. Ansible output: Re-run with `-v` flag
3. Jenkins logs: `/var/log/jenkins/jenkins.log` on EC2
4. AWS CloudTrail for infrastructure events

---

**Happy automating! 🚀**
