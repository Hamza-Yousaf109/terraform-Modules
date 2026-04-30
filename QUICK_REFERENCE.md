# ⚡ Quick Reference Card

## 🚀 Quick Start (3 Steps)

### 1. Configure AWS in Jenkins
```
Manage Jenkins → Credentials → Global
Add 3 credentials:
  • aws-access-key-id (Secret text)
  • aws-secret-access-key (Secret text)
  • devops-ssh-key (SSH private key)
```

### 2. Create Pipeline Job
```
New Item → Pipeline
Definition: Pipeline script from SCM
SCM: Git (your-repo-url)
Script Path: Jenkinsfile
```

### 3. Push Code & Deploy
```bash
# Deploy to dev
git add environments/dev/apply.tf
git commit -m "Update dev"
git push

# Jenkins auto-triggers
# Pipeline pauses for approval
# Click APPROVE & APPLY in Jenkins UI
```

---

## 🎯 Deployment Quick Start

### Deploy to Dev
```bash
cd environments/dev
nano apply.tf              # Edit as needed
git add apply.tf
git commit -m "Dev change"
git push
# Jenkins triggers → Terraform plan → Approval pause → Approve → Deploy
```

### Deploy to Stag
```bash
cd environments/stag
nano apply.tf              # Edit as needed
git add apply.tf
git commit -m "Stag promotion"
git push
# Jenkins triggers → Terraform plan → Approval pause → Approve → Deploy
```

### Deploy to Prod
```bash
cd environments/prod
nano apply.tf              # Edit as needed
git add apply.tf
git commit -m "Prod release"
git push
# Jenkins triggers → Terraform plan → Approval pause → Approve → Deploy
```

---

## 📋 Approval Workflow

| Step | What Happens |
|------|-------------|
| 1 | Developer pushes to environments/ENV/ |
| 2 | GitHub webhook triggers Jenkins |
| 3 | Jenkins detects changed environment |
| 4 | Terraform plan runs and displays |
| 5 | ⏸️ Pipeline pauses - Approval Required |
| 6 | Approver reviews Terraform plan |
| 7 | Approver clicks APPROVE & APPLY |
| 8 | Terraform apply runs |
| 9 | Ansible configures EC2 |
| 10 | ✓ Environment updated |

---

## 🔑 Key Commands

### Check if credentials exist
```bash
# In Jenkins Script Console:
Jenkins.instance.getItemByFullName("your-job").getProperty(hudson.model.ParametersDefinitionProperty.class)
```

### Test AWS credentials
```bash
aws sts get-caller-identity
```

### Test SSH access
```bash
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "echo OK"
```

### View Jenkins logs
```bash
# On Jenkins server
tail -100f /var/log/jenkins/jenkins.log
```

---

## 🔒 Approval Process

### For Approver
1. Open Jenkins Dashboard
2. Click the paused build
3. Scroll to "Terraform Apply" stage
4. Review Terraform plan
5. Click **APPROVE & APPLY** to proceed
6. Or click **ABORT** to cancel

### What to Check Before Approving
- [ ] Terraform plan shows expected changes
- [ ] No unexpected resource deletions
- [ ] Security groups are configured correctly
- [ ] Instance types are correct
- [ ] VPC and subnet settings look right
- [ ] This is the correct environment

---

## 📊 Approval Status

| Environment | Approval | Timeout | Approvers |
|------------|----------|---------|-----------|
| dev | ✅ Required | 24h | developers, admin |
| stag | ✅ Required | 24h | developers, admin |
| prod | ✅ Required | 24h | developers, admin |

---

## �� Troubleshooting

### Pipeline doesn't trigger
- Check GitHub webhook configured
- Check Jenkins job created
- Check Script Path is `Jenkinsfile`

### "Credentials not found" error
- Verify credential IDs in Jenkins:
  - `aws-access-key-id`
  - `aws-secret-access-key`
  - `devops-ssh-key`

### Approval button doesn't appear
- You're not in 'developers' or 'admin' group
- Contact Jenkins admin to add you

### SSH connection fails
- Ensure devops.pem is in Jenkins credentials
- Ensure EC2 security group allows port 22
- Test: `ssh -i ~/.ssh/devops.pem ubuntu@<IP>`

### Terraform apply fails
- Check AWS credentials are valid
- Check IAM user has EC2 permissions
- Check Terraform syntax: `terraform validate`

### Jenkins not accessible on EC2
- Wait 5-10 minutes (still installing)
- Check security group allows port 8080
- SSH to EC2 and check: `sudo systemctl status jenkins`

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `Jenkinsfile` | Pipeline definition |
| `ansible/playbook.yml` | Jenkins installation |
| `ansible/inventory.ini` | Ansible hosts |
| `scripts/terraform_to_ansible.py` | Glue script |
| `module/ec2/outputs.tf` | Terraform outputs |

---

## 🎯 Environment-Specific Paths

| Environment | Path | Purpose |
|-------------|------|---------|
| dev | `environments/dev/apply.tf` | Dev infrastructure |
| stag | `environments/stag/apply.tf` | Stag infrastructure |
| prod | `environments/prod/apply.tf` | Prod infrastructure |

---

## 💾 Git Workflow

```bash
# Standard workflow
git status                          # Check changes
git add environments/ENV/apply.tf   # Stage changes
git commit -m "Description"         # Commit
git push                            # Push to trigger Jenkins
```

---

## 🔐 Security Checklist

- [ ] AWS credentials stored in Jenkins (not in code)
- [ ] SSH keys stored in Jenkins (not in code)
- [ ] `.gitignore` includes `*.pem` files
- [ ] Never commit secrets to Git
- [ ] Only admins/leads approve prod changes
- [ ] Review Terraform plan before approving
- [ ] Check Jenkins logs for failed deployments

---

## 📈 Monitoring Deployments

### In Jenkins UI
1. Dashboard → Click job
2. See build history
3. Click build number
4. View **Console Output**

### In AWS Console
1. Go to EC2 → Instances
2. See instance status
3. Check instance details

### SSH to EC2
```bash
ssh -i ~/.ssh/devops.pem ubuntu@<PUBLIC-IP>
sudo systemctl status jenkins
curl http://localhost:8080
```

---

## 🎓 Common Scenarios

### I want to test in dev
```bash
git add environments/dev/apply.tf
git commit -m "Test: new instance type"
git push
# Pipeline auto-triggers, pauses for approval
# You approve it
```

### I want to promote to stag
```bash
cp environments/dev/apply.tf environments/stag/apply.tf
# Edit stag-specific values (larger instances, etc.)
git add environments/stag/apply.tf
git commit -m "Promote to stag"
git push
# Pipeline auto-triggers, pauses for approval
# Senior dev approves it
```

### I want to deploy to prod
```bash
cp environments/stag/apply.tf environments/prod/apply.tf
# Edit prod-specific values (highest performance)
git add environments/prod/apply.tf
git commit -m "Deploy to prod"
git push
# Pipeline auto-triggers, pauses for approval
# Admin approves it
```

---

## 📞 Help & Documentation

- **Full Pipeline Guide**: README.md
- **Approval Workflow**: APPROVAL_GATES.md
- **Developer Guide**: DEVELOPER_WORKFLOW.md
- **Jenkins Setup**: JENKINS_CREDENTIALS_SETUP.md
- **Quick Start**: QUICKSTART.md

---

**Version**: 1.0  
**Last Updated**: 2024-04-30  
**Status**: Production Ready ✅
