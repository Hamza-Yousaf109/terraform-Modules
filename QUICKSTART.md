# 🚀 Quick Start Guide

## What You Have

Your automated DevOps pipeline is now ready! Here's what was created:

### 📦 Key Files

1. **`Jenkinsfile`** - Jenkins pipeline definition
2. **`ansible/playbook.yml`** - Ansible playbook to install Jenkins
3. **`ansible/inventory.ini`** - Ansible inventory (auto-generated)
4. **`scripts/terraform_to_ansible.py`** - Glue script to bridge Terraform & Ansible
5. **`module/ec2/outputs.tf`** - Enhanced with Ansible-friendly outputs
6. **`README.md`** - Complete documentation

---

## 🎯 Quick Setup (5 Minutes)

### Step 1: Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, region, etc.
```

### Step 2: Apply Terraform
```bash
cd environments/dev
terraform init
terraform apply
# Review and approve (type: yes)
```

### Step 3: Generate Ansible Inventory
```bash
cd ../..
python3 scripts/terraform_to_ansible.py environments/dev ansible/inventory.ini
cat ansible/inventory.ini  # Check if EC2 IP is there
```

### Step 4: Run Ansible Playbook
```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -v
```

### Step 5: Access Jenkins
Once playbook finishes:
```
Jenkins URL: http://<EC2-PUBLIC-IP>:8080
```

---

## 🔑 SSH Key Setup

Make sure your `devops.pem` file exists:
```bash
# AWS EC2 → Key Pairs → Download devops.pem
mkdir -p ~/.ssh
chmod 600 ~/path-to/devops.pem

# For Ansible (add to ansible.cfg):
# private_key_file = ~/.ssh/devops.pem
```

---

## 🏗️ Pipeline Workflow

```
Push to GitHub
    ↓
GitHub Actions triggers
    ↓
Terraform provisions EC2
    ↓
Glue script generates inventory
    ↓
Ansible runs playbook
    ↓
Jenkins installed on EC2
    ↓
Jenkins accessible at http://IP:8080
```

---

## 📝 What Each Component Does

### Terraform (`environments/dev/`)
- Creates VPC
- Creates EC2 instance
- Creates security group
- Outputs instance details

### Glue Script (`scripts/terraform_to_ansible.py`)
- Reads Terraform outputs
- Extracts EC2 IP and details
- Writes to `ansible/inventory.ini`

### Ansible (`ansible/`)
- Connects via SSH
- Installs Java
- Installs Jenkins
- Starts Jenkins service

### Jenkins (`Jenkinsfile`)
- Orchestrates Terraform + Ansible
- Can be run from Jenkins UI
- Parameterized (select environment)

---

## ✅ Verification Commands

```bash
# Check Terraform output
cd environments/dev
terraform output -json | jq .instances_with_ssh

# Check Ansible inventory
cat ansible/inventory.ini

# Test SSH to EC2
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "echo OK"

# Check Jenkins status on EC2
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "sudo systemctl status jenkins"

# Get Jenkins password
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
```

---

## 🚨 Common Issues

### "Inventory hosts matched: 0"
- Run glue script: `python3 scripts/terraform_to_ansible.py environments/dev ansible/inventory.ini`
- Check inventory: `cat ansible/inventory.ini`

### "SSH connection refused"
- Wait 2-3 minutes for EC2 to fully boot
- Check security group allows port 22 (SSH)

### "Jenkins not accessible"
- Check EC2 is running: `aws ec2 describe-instances`
- Check security group allows port 8080
- Wait for Jenkins to start: `sudo systemctl status jenkins`

---

## 📚 Next Steps

1. **Access Jenkins**: Open `http://<EC2-IP>:8080` in browser
2. **Initial Setup**: Enter admin password (from EC2)
3. **Create Pipelines**: Create Jenkins jobs for your projects
4. **Scale**: Add more environments (stag, prod)

---

**You're all set! 🎉 Your DevOps pipeline is ready to go!**
