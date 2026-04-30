# 🔒 Jenkins Approval Gates & Deployment Safety

## Overview

Your Jenkins pipeline now has **approval gates for all environments** - every deployment requires human approval before applying infrastructure changes!

---

## 📋 Approval Workflow

### Environment-Based Approval Rules

| Environment | Approval Required | Use Case |
|------------|------------------|----------|
| **dev** | ✅ Yes (Required) | Testing with safety gate |
| **stag** | ✅ Yes (Required) | Pre-production validation |
| **prod** | ✅ Yes (Required) | Production deployment |

---

## 🎯 How It Works

### Scenario 1: Deploy to Dev (Approval Required)

```
Developer: git push to environments/dev/
                    ↓
Jenkins: Detects dev environment
                    ↓
Pipeline: Runs all validation stages
                    ↓
Terraform Plan completes
                    ↓
⏸️  PIPELINE PAUSES - WAITING FOR APPROVAL
                    ↓
Jenkins displays approval dialog:
  "⚠️ DEPLOYMENT APPROVAL REQUIRED
   Environment: DEV
   This will apply Terraform changes to: dev
   Review the plan output above and confirm:"
   [APPROVE & APPLY] or [ABORT]
                    ↓
Developer approves:
  • Clicks [APPROVE & APPLY]
                    ↓
✓ Terraform applies
✓ Ansible configures
                    ↓
Dev is updated ✓
```

### Scenario 2: Deploy to Stag (Approval Required)

```
Developer: git push to environments/stag/
                    ↓
Jenkins: Detects stag environment
                    ↓
Pipeline: Runs validation stages
                    ↓
Terraform Plan stage completes
                    ↓
⏸️  PIPELINE PAUSES - WAITING FOR APPROVAL
                    ↓
Jenkins displays approval dialog:
  "⚠️ DEPLOYMENT APPROVAL REQUIRED
   Environment: STAG
   This will apply Terraform changes to: stag
   Review the plan output above and confirm:"
   [APPROVE & APPLY] or [ABORT]
                    ↓
Senior Team Member reviews and approves:
  • Checks Terraform plan output
  • Verifies no harmful changes
  • Clicks [APPROVE & APPLY]
                    ↓
✓ Terraform applies
✓ Ansible configures
                    ↓
Stag is updated ✓
```

### Scenario 3: Deploy to Prod (Approval Required)

Same as Stag - requires manual approval before applying!

---

## 👤 Who Can Approve Deployments?

In your `Jenkinsfile`, the approval step specifies:

```groovy
submitter: 'developers,admin'
```

This means only users in these groups can approve:
- Users in Jenkins group: `developers`
- Users in Jenkins group: `admin`

### To Configure Approval Groups:

1. **Manage Jenkins** → **Configure Global Security**
2. Security Realm: Select your authentication system
3. User/Group mapping (depends on your auth)

---

## 🔄 Approval Step-by-Step

### For an Approver

When a stag/prod deployment is pending approval:

#### Step 1: Notification
Jenkins sends notification (email, Slack, etc.):
```
🚨 Approval Required: terraform-ansible-pipeline #42
Environment: stag
Requested by: developer@company.com
Action needed: Review and approve deployment
```

#### Step 2: Review Pipeline
1. Open Jenkins Dashboard
2. Click the pipeline build (e.g., #42)
3. Scroll to "Terraform Apply" stage
4. See the approval dialog

#### Step 3: Review Terraform Plan
```
Before approval, you should see:

Plan: 1 to add, 0 to change, 0 to destroy.

This shows EXACTLY what will change!

Examples:
  + aws_instance.app[0]           (will create)
  + aws_security_group.default[0] (will create)
  ~ aws_vpc.example               (will modify)
  - aws_subnet.old_subnet         (will destroy)
```

#### Step 4: Make Decision
- ✅ **APPROVE & APPLY** - If changes look correct
- ❌ **ABORT** - If something looks wrong

#### Step 5: Approval Submitted
```
Approval submitted by: approver@company.com
Timestamp: 2024-04-30 14:32:15 UTC
Action: APPROVED
Comment: "Reviewed and approved. Ready for stag."
```

---

## ⏳ Timeout for Approvals

By default, Jenkins waits **24 hours** for approval. If no one approves:

```
Pipeline Status: ABORTED (timeout)
Message: "Input step 'ApproveDeployment' timed out after 24 hours"
```

You can change this timeout in Jenkinsfile:

```groovy
def userApproval = input(
    id: 'ApproveDeployment',
    message: '⚠️  DEPLOYMENT APPROVAL REQUIRED...',
    ok: 'APPROVE & APPLY',
    submitter: 'developers,admin',
    timeout: 30,              // ← 30 minutes timeout
    timeoutUnit: 'MINUTES'
)
```

### Recommended Timeout by Environment

```groovy
if (env.DETECTED_ENV == 'dev') {
    timeout(time: 30, unit: 'MINUTES')  // Quick approval for dev
} else if (env.DETECTED_ENV == 'stag') {
    timeout(time: 4, unit: 'HOURS')     // Reasonable time for stag
} else if (env.DETECTED_ENV == 'prod') {
    timeout(time: 24, unit: 'HOURS')    // Careful review for prod
}
```

---

## 📧 Approval Notifications

### Enable Email Notifications

1. **Manage Jenkins** → **Configure System**
2. Find **E-mail Notification** section
3. Enter SMTP server details:
   - SMTP server: `smtp.gmail.com` or your mail server
   - Default user e-mail suffix: `@company.com`
   - Reply-To Address: `jenkins@company.com`

4. In your pipeline job:
   - **Post-build Actions**
   - **E-mail Notification**
   - Recipients: `team@company.com`

### Enable Slack Notifications

1. Install **Slack Notification Plugin**
   - Manage Jenkins → Plugin Manager
   - Search for: Slack

2. Configure Slack:
   - Manage Jenkins → Configure System
   - Slack section → Webhook URL: `https://hooks.slack.com/...`

3. In pipeline, add to `post` section:

```groovy
post {
    always {
        slackSend(
            color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
            message: "Approval needed for: ${env.DETECTED_ENV}",
            webhookUrl: "${SLACK_WEBHOOK}"
        )
    }
}
```

---

## 🚨 Safety Features

### What Approval Prevents

✅ **Prevents accidental prod deployments**
```
Developer accidentally pushed to prod?
Pipeline pauses → Approval required → Team reviews → Can abort
```

✅ **Prevents harmful infrastructure changes**
```
Terraform plan shows:
  - aws_db_instance.production (destroying database!)
Senior dev reviews → Clicks ABORT → Disaster prevented!
```

✅ **Audit trail**
```
Jenkins logs:
  "Terraform apply to stag approved by: john@company.com"
  "Timestamp: 2024-04-30 14:32:15"
  "Comment: Reviewed all changes, looks good"
```

✅ **Team coordination**
```
Multiple teams can review before approval:
  - Infrastructure team approves infrastructure
  - App team approves configuration
  - Security team approves access rules
```

---

## 🔧 Customize Approval for Your Needs

### Option 1: Different Approval Requirements per Environment

```groovy
// In Jenkinsfile - require approval only for stag and prod:
if (env.DETECTED_ENV == 'dev') {
    echo "✅ Dev: auto-approved for quick testing"
    // No approval needed
} else if (env.DETECTED_ENV == 'stag' || env.DETECTED_ENV == 'prod') {
    input(...)  // Require approval for stag/prod
}
```

### Option 2: Approval for All (Current Setup)

```groovy
// Require approval for all environments:
def userApproval = input(...)  // Always show approval dialog
```

### Option 3: Different Approvers per Environment

```groovy
if (env.DETECTED_ENV == 'dev') {
    input(submitter: 'developers')      // Devs approve dev
} else if (env.DETECTED_ENV == 'stag') {
    input(submitter: 'lead,admin')      // Leads approve stag
} else if (env.DETECTED_ENV == 'prod') {
    input(submitter: 'admin,manager')   // Admins/managers approve prod
}
```

### Option 4: Require Comments/Reason

```groovy
def userApproval = input(
    id: 'ApproveDeployment',
    message: 'APPROVAL REQUIRED',
    ok: 'APPROVE & APPLY',
    submitter: 'developers,admin',
    parameters: [
        string(
            name: 'APPROVAL_REASON',
            description: 'Why are you approving this deployment?'
        )
    ]
)
echo "Approved by: ${userApproval}"
```

---

## 📊 Approval Workflow Examples

### Example 1: Dev Deploy (With Approval)

```
Push to: environments/dev/apply.tf
         ↓
Jenkins triggers
         ↓
Terraform plan shown
         ↓
⏸️  PAUSED - Waiting for approval
         
Developer reviews:
  • Checks Terraform plan
  • Verifies changes are correct
  ↓
Developer approves: "Looks good!"
         ↓
Terraform apply (approved)
         ↓
Ansible runs
         ↓
✓ Dev updated (~5 minutes total)
```

### Example 2: Stag Deploy (With Approval)

```
Push to: environments/stag/apply.tf
         ↓
Jenkins triggers
         ↓
Terraform plan shown
         ↓
⏸️  PAUSED - Waiting for approval
         
Time: 2:32 PM
Email sent to: team@company.com
Slack notification sent
         
Senior Dev reviews:
  • Checks Terraform plan
  • Verifies security group changes
  • Reviews instance sizes
  ↓
Senior Dev approves: "Looks good!"
         ↓
Terraform apply (approved)
         ↓
Ansible runs
         ↓
✓ Stag updated (~5 minutes + approval time)
```

### Example 3: Prod Deploy (With Approval)

```
Create PR: feature/prod-release
         ↓
Code review: ✓ Approved by 2 reviewers
         ↓
Merge to main
         ↓
Jenkins triggers
         ↓
Terraform plan shown (very carefully reviewed!)
         ↓
⏸️  PAUSED - Waiting for APPROVALS
         
Lead: Reviews and approves plan
         ↓
All approvals received
         ↓
Terraform apply
         ↓
Ansible configures
         ↓
✓ Prod updated (with confidence!)
```

---

## 🎯 Best Practices

### ✅ DO:

1. **Always review the Terraform plan** before approving
   ```
   Look for:
   • Unexpected resource deletions
   • Security group changes
   • Database modifications
   • Data loss risks
   ```

2. **Have clear approval criteria**
   ```
   Example policy:
   - Dev: No approval needed
   - Stag: 1 dev approval
   - Prod: 2 approvals (dev lead + manager)
   ```

3. **Document approval reasons**
   ```
   "Approved - updated instance type for performance"
   "Approved - added new security group rule for API"
   ```

4. **Keep audit logs**
   ```
   Jenkins automatically logs:
   - Who approved
   - When they approved
   - What they approved
   ```

5. **Test in dev first**
   ```
   Dev (no approval) → Stag (approval) → Prod (approval)
   This reduces risks!
   ```

### ❌ DON'T:

1. Approve without reviewing Terraform plan
2. Click approve just because the process is slow
3. Approve prod changes on Fridays (can't fix issues over weekend)
4. Share approval credentials with others
5. Bypass approval gates manually

---

## 🧪 Test Approval Flow

### Simulate Stag Deployment

```bash
# 1. Make a change to stag
cd environments/stag
echo 'instance_type = "t3.large"' >> apply.tf

# 2. Commit and push
git add apply.tf
git commit -m "Test stag approval flow"
git push origin main

# 3. Watch Jenkins
# Pipeline will pause at "Terraform Apply" stage
# Waiting for approval

# 4. Go to Jenkins UI
# Click the paused build
# You'll see approval dialog

# 5. Click "APPROVE & APPLY"
# Pipeline continues

# 6. Check console output
# Should show approval info
```

---

## 📞 Troubleshooting

### "Input step timed out after 24 hours"

**Problem:** Nobody approved the deployment

**Solution:**
1. Extend timeout in Jenkinsfile
2. Set up notifications (email/Slack)
3. Define clear approval SLA (e.g., 4 hours)

### "I don't see the approval dialog"

**Problem:** You're not in the approver group

**Solution:**
1. Contact Jenkins admin
2. Add yourself to `developers` or `admin` group
3. Update `submitter: 'developers,admin'` in Jenkinsfile

### "Approval was submitted but pipeline didn't continue"

**Problem:** Pipeline failed in another stage

**Solution:**
1. Check console output for errors
2. Fix the error (usually AWS credentials or Terraform syntax)
3. Re-run the pipeline

---

## 🎓 Learning Outcomes

By using approval gates, you learn:

✅ **CI/CD Best Practices**
- Approval gates prevent errors
- Multiple environments reduce risks
- Audit trails provide accountability

✅ **Team Workflow**
- Cross-team approvals
- Knowledge sharing
- Responsibility

✅ **Risk Management**
- Review before production
- Catch mistakes early
- Rollback capability

✅ **DevOps Maturity**
- Automated pipelines with safeguards
- Balance speed and safety
- Production readiness

---

## 🚀 Summary

Your Jenkins pipeline now has:

| Environment | Approval | Purpose |
|------------|----------|---------|
| **dev** | ❌ Auto | Fast iteration, testing |
| **stag** | ✅ Manual | Pre-production validation |
| **prod** | ✅ Manual | Production safety |

**This is production-ready DevOps! 🎉**

---

**Next Step:** Create your first stag deployment and test the approval flow!
