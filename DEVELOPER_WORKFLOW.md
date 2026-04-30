# 📚 Developer Deployment Workflow Guide

## Quick Reference: How to Deploy to Different Environments

### 🎯 For Developers: Auto-Detect Deployment

When you push code changes to specific environment folders, Jenkins **automatically detects** and deploys to the correct environment!

---

## Step-by-Step Deployment Examples

### Example 1: Deploy to DEV Environment

You want to test infrastructure changes in the dev environment:

```bash
# 1. Clone the repository
git clone https://github.com/your-org/terraform-repo.git
cd terraform-repo

# 2. Make changes to dev environment
nano environments/dev/apply.tf
# Edit instance_type, vpc_cidr, etc.

# 3. Commit and push to dev
git add environments/dev/apply.tf
git commit -m "Update dev instance type to t3.large"
git push origin main

# Jenkins automatically detects:
# ✓ Changes in environments/dev/
# ✓ Triggers pipeline
# ✓ Deploys to DEV only
# ✓ Runs Ansible on DEV instances
```

**Result:**
- ✓ EC2 instance updated in dev
- ✓ Jenkins installed on dev EC2
- ✓ Stag and prod remain untouched

---

### Example 2: Deploy to STAG Environment

You want to promote infrastructure to staging:

```bash
# 1. Navigate to staging environment directory
cd environments/stag

# 2. Copy configuration from dev (if needed)
cp ../dev/apply.tf apply.tf

# 3. Make stag-specific changes
nano apply.tf
# Change: instance_type = "t3.xlarge" (larger for stag)
#         vpc_cidr = "10.1.0.0/24" (different CIDR)

# 4. Commit and push to stag
git add apply.tf
git commit -m "Promote to stag: larger instance and separate VPC"
git push origin main

# Jenkins automatically detects:
# ✓ Changes in environments/stag/
# ✓ Triggers pipeline
# ✓ Deploys to STAG only
# ✓ Runs Ansible on STAG instances
```

**Result:**
- ✓ EC2 instance updated in stag
- ✓ Jenkins installed on stag EC2
- ✓ Dev and prod remain untouched

---

### Example 3: Deploy to PROD Environment

You want to deploy to production (requires manual approval):

```bash
# 1. Make prod-specific changes
cd environments/prod
nano apply.tf
# Change: instance_type = "t3.2xlarge" (production grade)
#         backup_enabled = true
#         monitoring_enabled = true

# 2. Create a feature branch (not main)
git checkout -b feature/prod-deployment

# 3. Commit changes
git add apply.tf
git commit -m "Production deployment: high-capacity instances"

# 4. Push feature branch
git push origin feature/prod-deployment

# 5. Create Pull Request
# (GitHub UI: Compare & pull request)
# Description: "Deploying to production with high-capacity instances"

# 6. Team review and approve PR
# (Code review in GitHub)

# 7. Merge to main
# Jenkins detects:
# ✓ Changes in environments/prod/
# ✓ Triggers pipeline
# ✓ Deploys to PROD (with confirmation)
```

**Result:**
- ✓ EC2 instance updated in prod
- ✓ Jenkins installed on prod EC2
- ✓ Dev and stag remain untouched

---

## Directory Structure: Where to Make Changes

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── apply.tf          ← Edit HERE for dev changes
│   │   ├── provider.tf
│   │   └── backend.tf
│   │
│   ├── stag/
│   │   ├── apply.tf          ← Edit HERE for stag changes
│   │   ├── provider.tf
│   │   └── backend.tf
│   │
│   └── prod/
│       ├── apply.tf          ← Edit HERE for prod changes
│       ├── provider.tf
│       └── backend.tf
│
├── module/
│   ├── ec2/                  ← Generic modules (don't edit per-env)
│   ├── vpc/
│   └── s3/
```

**Important:** 
- ✅ Edit `environments/XXX/apply.tf` to deploy to that environment
- ❌ Don't edit `module/` files to change specific environment behavior
- ✅ Use `environments/XXX/` to override module variables per environment

---

## Typical Development Workflow

### Day 1: Test in Dev
```bash
# Make changes to dev
git add environments/dev/apply.tf
git commit -m "WIP: Testing new VPC setup"
git push

# Jenkins auto-deploys to dev
# Test Jenkins on dev EC2
# Verify everything works
```

### Day 2: Promote to Stag
```bash
# Copy working config to stag
cp environments/dev/apply.tf environments/stag/apply.tf

# Adjust for stag (more resources, prod-like)
git add environments/stag/apply.tf
git commit -m "Promote dev setup to staging"
git push

# Jenkins auto-deploys to stag
# Run more tests
```

### Day 3: Deploy to Prod
```bash
# Create release branch
git checkout -b release/v1.0

# Copy stag config to prod
cp environments/stag/apply.tf environments/prod/apply.tf

# Add prod hardening
git add environments/prod/apply.tf
git commit -m "Production release v1.0"

# Create PR for review
git push origin release/v1.0

# After approval, merge to main
# Jenkins auto-deploys to prod
```

---

## Jenkins Pipeline Parameters (Manual Trigger)

If you need to manually trigger the pipeline:

### In Jenkins UI:

1. Go to your pipeline job
2. Click **Build with Parameters**
3. Set these options:

#### ENVIRONMENT
- **auto-detect** (Default) - Jenkins reads your git changes
  - If you pushed to `environments/dev/` → deploys to dev
  - If you pushed to `environments/stag/` → deploys to stag
  - If you pushed to `environments/prod/` → deploys to prod

- **dev** / **stag** / **prod** - Force specific environment

#### APPLY_TERRAFORM
- **Unchecked** - Terraform plan only (see what would change)
- **Checked** ✓ - Terraform apply (create/modify resources)

#### RUN_ANSIBLE
- **Unchecked** - Skip Jenkins installation
- **Checked** ✓ - Install Jenkins via Ansible

### Safe Deployment Process:

1. **First Build** (Terraform Plan Only)
   ```
   ENVIRONMENT: auto-detect
   APPLY_TERRAFORM: ❌ (unchecked)
   RUN_ANSIBLE: ❌ (unchecked)
   ```
   → See what will change, no actual modifications

2. **Second Build** (Apply Infrastructure)
   ```
   ENVIRONMENT: auto-detect
   APPLY_TERRAFORM: ✓ (checked)
   RUN_ANSIBLE: ❌ (unchecked)
   ```
   → Creates/modifies EC2 instances

3. **Third Build** (Configure with Ansible)
   ```
   ENVIRONMENT: auto-detect
   APPLY_TERRAFORM: ❌ (unchecked)
   RUN_ANSIBLE: ✓ (checked)
   ```
   → Installs Jenkins on the instances

---

## Example: What Changes Get Deployed Where

### Your Change Tracking:

```bash
# Check what environment your changes affect
git diff HEAD~1 HEAD --name-only

# Example 1: Only dev changes
environments/dev/apply.tf                    ← Jenkins deploys to dev
ansible/playbook.yml                         ← Used by all environments

# Example 2: Dev and module changes
environments/dev/apply.tf                    ← Jenkins deploys to dev
module/ec2/main.tf                           ← Affects all, but dev triggered

# Example 3: Stag only
environments/stag/apply.tf                   ← Jenkins deploys to stag only
```

---

## 🚨 Important Rules

### ✅ DO:
- Commit to specific `environments/XXX/` folders
- Test in dev before promoting to stag
- Test in stag before deploying to prod
- Create pull requests for prod changes
- Always review what Terraform will change

### ❌ DON'T:
- Edit `module/` files to test environment-specific changes
- Push directly to main for prod changes (use PR)
- Force apply without reviewing plan first
- Deploy to prod on Fridays (let it stabilize)

---

## Monitoring Deployments

### View Jenkins Pipeline Status:

1. Go to Jenkins Dashboard
2. Click your pipeline job
3. See build history with:
   - ✓ Green = Success
   - ✗ Red = Failed
   - ⏳ Blue = In Progress

### View Console Output:

1. Click the build number
2. Click **Console Output**
3. See step-by-step execution:
   ```
   🔄 Checking out code...
   🔍 Detecting changed environment...
   ✓ Auto-detected changes in: dev
   🔐 Configuring AWS credentials...
   ✓ Terraform validation successful
   ...
   ✓ Jenkins is running!
   ```

### Access Deployed Jenkins:

After successful Ansible run:
```
Jenkins URL: http://<EC2-PUBLIC-IP>:8080
Initial Admin Password: cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## Troubleshooting: Why Didn't My Code Deploy?

### Symptom: "No environment changes detected"

**Cause:** You edited files outside `environments/XXX/`

**Fix:** Edit only:
- `environments/dev/apply.tf` for dev
- `environments/stag/apply.tf` for stag
- `environments/prod/apply.tf` for prod

### Symptom: "Pipeline deployed to dev but I wanted stag"

**Cause:** You edited `environments/dev/` instead of `environments/stag/`

**Fix:** Double-check git diff:
```bash
git diff HEAD~1 HEAD --name-only | grep environments
# Should show environments/stag/apply.tf
```

### Symptom: "Jenkins not accessible after deployment"

**Cause:** Ansible playbook failed or EC2 security group blocks port 8080

**Fix:**
1. Check pipeline console output for errors
2. SSH to EC2 and check Jenkins:
   ```bash
   ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP>
   sudo systemctl status jenkins
   ```
3. Check AWS security group allows inbound 8080

---

## 🎓 Summary: Environment-Specific Deployments

| Action | Command | Result |
|--------|---------|--------|
| Edit & push to dev | `git push` from `environments/dev/` | Jenkins auto-deploys to dev |
| Edit & push to stag | `git push` from `environments/stag/` | Jenkins auto-deploys to stag |
| Edit & push to prod | Create PR, merge to main | Jenkins auto-deploys to prod |
| Manual trigger | Jenkins UI → Build with Parameters | Deploy to specified environment |
| View status | Jenkins Dashboard | See build history & logs |

---

## 🚀 You're Ready!

Your developers can now:
- ✅ Make changes in specific environment folders
- ✅ Push code
- ✅ Jenkins automatically detects and deploys to correct environment
- ✅ No manual environment selection needed
- ✅ Dev, stag, and prod stay isolated

**Happy deploying! 🎉**
