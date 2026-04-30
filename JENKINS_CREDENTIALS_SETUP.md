# 🔐 Jenkins AWS Credentials Setup Guide

## Prerequisites
- Jenkins instance running
- Admin access to Jenkins
- AWS IAM credentials (Access Key ID and Secret Access Key)

---

## Step 1: Create AWS IAM User (Recommended)

Instead of using root AWS credentials, create an IAM user with minimal permissions:

### In AWS Console:
1. Go to **IAM** → **Users** → **Create User**
2. Username: `jenkins-deployer`
3. Select **Programmatic access**
4. Create access key (this gives you Access Key ID & Secret Access Key)
5. Attach policy: **AmazonEC2FullAccess** (for Terraform to manage EC2)

---

## Step 2: Add AWS Credentials to Jenkins

### Method 1: Via Jenkins Web UI (Recommended for Students)

1. **Open Jenkins Dashboard**
   - Go to `http://your-jenkins-url:8080`
   - Login with admin credentials

2. **Navigate to Credentials**
   - Click **Manage Jenkins** (left sidebar)
   - Click **Credentials**
   - Click **System** 
   - Click **Global credentials**

3. **Add AWS Access Key ID**
   - Click **+ Add Credentials**
   - Kind: **Secret text**
   - Secret: `your-AWS-ACCESS-KEY-ID`
   - ID: `aws-access-key-id`
   - Description: `AWS Access Key ID for Terraform`
   - Click **Create**

4. **Add AWS Secret Access Key**
   - Click **+ Add Credentials**
   - Kind: **Secret text**
   - Secret: `your-AWS-SECRET-ACCESS-KEY`
   - ID: `aws-secret-access-key`
   - Description: `AWS Secret Access Key for Terraform`
   - Click **Create**

5. **Add SSH Private Key (devops.pem)**
   - Click **+ Add Credentials**
   - Kind: **SSH Username with private key**
   - Username: `ubuntu`
   - ID: `devops-ssh-key`
   - Private Key: Upload or paste your `devops.pem` file
   - Passphrase: (leave empty if no passphrase)
   - Click **Create**

---

## Step 3: Verify Credentials Were Added

```bash
# On Jenkins server (via SSH), check if credentials are available
# They should be listed in Jenkins UI under Credentials
```

---

## Step 4: Configure Jenkins Pipeline Job

### Option A: From Git Repository (Webhook-Based)

1. **Create New Pipeline Job**
   - Jenkins Dashboard → **New Item**
   - Name: `terraform-ansible-pipeline`
   - Type: **Pipeline**
   - Click **OK**

2. **Configure Pipeline**
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/your-user/your-terraform-repo`
   - **Branch**: `*/main` or `*/develop`
   - **Script Path**: `Jenkinsfile`

3. **Configure Build Triggers**
   - Enable **GitHub hook trigger for GITScm polling**
   - OR Enable **Poll SCM** and set schedule: `H/15 * * * *` (every 15 minutes)

4. **Save**

### Option B: Manual Trigger (for Testing)

1. Create a Pipeline job (same as above)
2. Run it manually from Jenkins UI
3. Select parameters:
   - Environment: `auto-detect` (reads from git changes)
   - Apply Terraform: ✓
   - Run Ansible: ✓

---

## Step 5: Configure GitHub Webhook (Optional, for Auto-Trigger)

If you want Jenkins to automatically trigger on git push:

### In GitHub Repository:

1. **Settings** → **Webhooks** → **Add Webhook**
2. **Payload URL**: `http://your-jenkins-url:8080/github-webhook/`
3. **Content type**: `application/json`
4. **Events**: 
   - ✓ Push events
   - ✓ Pull requests
5. **Click Add webhook**

### In Jenkins (if not already done):
1. Install **GitHub plugin** (Manage Jenkins → Plugin Manager)
2. GitHub Server configuration (Manage Jenkins → Configure System)

---

## 🎯 How Environment Detection Works

When you push changes:

### Dev Environment
```bash
# Push changes to environments/dev/
git add environments/dev/apply.tf
git commit -m "Update dev environment"
git push
```
→ Jenkins detects `environments/dev/` changes → Auto-detects environment as `dev` → Applies to `dev` only ✓

### Stag Environment
```bash
# Push changes to environments/stag/
git add environments/stag/apply.tf
git commit -m "Update stag environment"
git push
```
→ Jenkins detects `environments/stag/` changes → Auto-detects environment as `stag` → Applies to `stag` only ✓

### Prod Environment
```bash
# Push changes to environments/prod/
git add environments/prod/apply.tf
git commit -m "Update prod environment"
git push
```
→ Jenkins detects `environments/prod/` changes → Auto-detects environment as `prod` → Applies to `prod` only ✓

---

## 📋 Pipeline Parameters Explained

When running the pipeline manually, you'll see:

### 1. **ENVIRONMENT**
   - `auto-detect` (default) - Reads from git changed files
   - `dev` - Force dev environment
   - `stag` - Force stag environment
   - `prod` - Force prod environment

### 2. **APPLY_TERRAFORM**
   - Unchecked = Plan only (safe, no changes)
   - ✓ Checked = Apply changes (creates resources)

### 3. **RUN_ANSIBLE**
   - Unchecked = Skip Ansible
   - ✓ Checked = Install Jenkins on EC2

---

## 🔧 Jenkins Configuration File (credentials.xml)

Jenkins stores encrypted credentials in `~/.jenkins/credentials.xml`. You can also configure them via:

```groovy
// Script Console (Manage Jenkins → Script Console)
// Create credentials programmatically:

import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret

def store = Jenkins.instance.getExtensionList(
    'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
)[0].getStore()

// Example: Add secret text credential
def domain = Domain.global()
def cred = new StringCredentialsImpl(
    CredentialsScope.GLOBAL,
    "aws-access-key-id",
    "AWS Access Key ID",
    Secret.fromString("YOUR_ACCESS_KEY")
)
store.addCredentials(domain, cred)
Jenkins.instance.save()
```

---

## 🧪 Testing Your Setup

### Test 1: Verify AWS Credentials

```bash
# In Jenkins Script Console:
sh 'aws sts get-caller-identity'
```

Expected output:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/jenkins-deployer"
}
```

### Test 2: Verify SSH Access

```bash
# In pipeline or via Jenkins SSH
ssh -i ~/.ssh/devops.pem ubuntu@<EC2-IP> "echo 'SSH works!'"
```

### Test 3: Run Pipeline

1. Go to Jenkins Dashboard
2. Click your pipeline job
3. Click **Build with Parameters**
4. Set:
   - Environment: `dev`
   - Apply Terraform: ✓
   - Run Ansible: ✓
5. Click **Build**
6. Watch console output

---

## 🚨 Troubleshooting

### Error: "aws-access-key-id credential not found"

**Solution:**
1. Go to Manage Jenkins → Credentials
2. Verify both credentials exist:
   - `aws-access-key-id`
   - `aws-secret-access-key`
   - `devops-ssh-key`
3. If missing, add them (see Step 2)

### Error: "Unable to locate credentials"

**Solution:**
1. Check credential IDs match exactly in Jenkinsfile:
   ```groovy
   withCredentials([
       string(credentialsId: 'aws-access-key-id', ...),
       string(credentialsId: 'aws-secret-access-key', ...)
   ])
   ```

2. Verify in Jenkins UI that these IDs exist

### Error: "Terraform apply: AWS authentication failed"

**Solution:**
1. Verify IAM user has EC2 permissions:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": "ec2:*",
               "Resource": "*"
           }
       ]
   }
   ```

2. Test credentials manually:
   ```bash
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   aws ec2 describe-instances --region us-east-1
   ```

### Error: "SSH: Command 'ssh-keyscan' failed"

**Solution:**
1. Ensure SSH key is in Jenkins credentials
2. Try adding host manually:
   ```bash
   ssh-keyscan -H <EC2-IP> >> ~/.ssh/known_hosts
   ```

---

## 📊 Pipeline Execution Flow

```
Developer Push to dev/
         ↓
GitHub Webhook triggers Jenkins
         ↓
Jenkins checkout code
         ↓
Detect changed environment: dev
         ↓
AWS Credentials Check ✓
         ↓
Terraform Validate (environments/dev/)
         ↓
[PARAM: APPLY_TERRAFORM?]
    ├─ Yes → Terraform Apply
    └─ No → Stop here
         ↓
[PARAM: RUN_ANSIBLE?]
    ├─ Yes → Generate Inventory & Run Playbook
    └─ No → Stop here
         ↓
Verify Jenkins Installation
         ↓
✓ Pipeline Complete!
```

---

## 📝 Credential Security Best Practices

✅ **Do:**
- Use IAM users instead of root credentials
- Rotate credentials regularly
- Use Secret text type for sensitive values
- Never commit credentials to Git
- Use `.gitignore` to exclude `.pem` files
- Regularly audit Jenkins credentials

❌ **Don't:**
- Share credentials in chat or email
- Commit credentials to Git
- Use root AWS credentials
- Store credentials in plain text
- Share `devops.pem` file publicly

---

## 🎓 Environment Setup Summary

| Item | Value | Created By |
|------|-------|-----------|
| AWS Access Key | Secret text | IAM User |
| AWS Secret Key | Secret text | IAM User |
| SSH Private Key | devops.pem | You (AWS EC2 Key Pair) |
| Jenkins Pipeline | Jenkinsfile | Provided |
| Environment Detection | Auto | Pipeline Logic |

---

**Your Jenkins pipeline is now ready for environment-specific deployments! 🚀**
