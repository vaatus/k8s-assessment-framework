# Kubernetes Assessment Framework - Instructor Guide

## Overview

This framework enables instructors to deploy a complete Kubernetes assessment system where students can:
- Deploy their own K3s cluster in AWS Learner Lab
- Complete assigned Kubernetes tasks
- Request automated evaluation of their work
- Submit final results for grading

**Architecture**: Cross-account setup where instructor's Lambda functions remotely evaluate student clusters via Kubernetes API.

---

## Prerequisites

### Instructor AWS Account (AWS Learner Lab)
- Active AWS Learner Lab session
- AWS CLI configured with credentials
- Python 3.x installed
- `jq` installed (optional but recommended)

### Student AWS Accounts (AWS Learner Lab)
- Each student needs their own AWS Learner Lab account
- SSH key pair created (usually `vockey`)
- Unique 6-character Neptun Code

---

## One-Time Setup (Instructor)

### Step 1: Clone Repository

```bash
git clone <repository-url>
cd k8s-assessment-framework
```

### Step 2: Deploy Complete Infrastructure

Run the **single source of truth** deployment script:

```bash
cd instructor-tools
./deploy-complete-setup.sh
```

This script performs ALL necessary setup:
1. ✅ Creates S3 buckets (results and templates)
2. ✅ Deploys evaluation Lambda with dependencies (PyYAML, requests)
3. ✅ Deploys submission Lambda
4. ✅ Configures CloudFormation template with endpoints
5. ✅ Uploads template to S3
6. ✅ Creates and uploads student landing page
7. ✅ Generates all necessary credentials

**Duration**: 3-5 minutes

### Step 3: Save Critical Information

The script creates three files in `instructor-tools/`:
- `EVALUATION_ENDPOINT.txt` - Lambda URL for evaluation
- `SUBMISSION_ENDPOINT.txt` - Lambda URL for submission
- `API_KEY.txt` - Authentication key (chmod 600)

**⚠️ IMPORTANT**: Keep these files safe. They are needed for:
- Re-uploading the template with `./reupload-template.sh`
- Debugging issues
- Redeploying after AWS Learner Lab session expires

### Step 4: Share Landing Page with Students

After deployment completes, share this URL with students:

```
https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html
```

---

## Student Deployment Process

Students will:
1. Visit the landing page
2. Click "Deploy My Environment"
3. Sign in to their AWS Learner Lab
4. Enter their Neptun Code (e.g., TEST01)
5. Select their assigned task (task-01, task-02, or task-03)
6. Create stack (takes 5-10 minutes)
7. SSH to their EC2 instance
8. Complete the task and request evaluation

**Everything is automated** - no manual intervention needed from instructor!

---

## Directory Structure

```
k8s-assessment-framework/
├── cloudformation/
│   └── unified-student-template.yaml          # Student CloudFormation template
├── evaluation/
│   └── lambda/
│       ├── evaluator.py                       # Evaluation Lambda function
│       └── requirements.txt                   # Python dependencies
├── submission/
│   └── lambda/
│       └── submitter.py                       # Submission Lambda function
├── instructor-tools/
│   ├── deploy-complete-setup.sh               # ⭐ ONE SCRIPT TO DEPLOY EVERYTHING
│   ├── test-complete-deployment.sh            # Test framework deployment
│   ├── reupload-template.sh                   # Re-upload template only
│   ├── view-results.sh                        # View student submissions
│   └── check-prerequisites.sh                 # Pre-deployment checks
├── legacy-scripts/                            # Archived old scripts
└── INSTRUCTOR_GUIDE.md                        # This file
```

---

## Key Files Explained

### `deploy-complete-setup.sh` ⭐
**The single source of truth for complete deployment.**

What it does:
- Creates/configures S3 buckets
- Packages Lambda functions WITH dependencies
- Deploys/updates Lambda functions with correct environment variables
- Updates CloudFormation template with Lambda endpoints
- Uploads template to S3
- Creates student landing page
- Saves all credentials locally

**When to use**:
- First-time setup
- After AWS Learner Lab session expires (need to redeploy)
- When Lambda code changes
- When fixing issues (re-run to update everything)

### `unified-student-template.yaml`
CloudFormation template that students use to deploy their environment.

Contains:
- VPC with public subnet
- EC2 instance (t3.medium)
- K3s installation
- Kyverno installation
- Service account for remote evaluation
- Student tools (evaluation and submission scripts)
- Task workspace with README
- Auto-shutdown after 4 hours

**Variables substituted by deployment script**:
- `${EvaluationEndpoint}` - Evaluation Lambda URL
- `${SubmissionEndpoint}` - Submission Lambda URL
- `${ApiKey}` - Authentication key

### `evaluator.py`
Lambda function that remotely connects to student K3s clusters.

Features:
- API key authentication
- Connects to K3s via service account token
- Validates deployment exists
- Checks replicas, pods, services
- Stores results in S3
- Returns eval_token for submission

**Dependencies**: PyYAML, requests (packaged automatically)

### `submitter.py`
Lambda function that processes final submissions.

Features:
- API key authentication
- Validates eval_token from previous evaluation
- Stores final submission in S3
- Prevents duplicate submissions

---

## Testing the Framework

### Test 1: Infrastructure Test

```bash
cd instructor-tools
./test-complete-deployment.sh
```

This tests:
- ✅ AWS credentials
- ✅ S3 buckets exist
- ✅ Lambda functions deployed
- ✅ Function URLs configured
- ✅ Template uploaded and publicly accessible
- ✅ Landing page accessible
- ✅ API key authentication

Expected: All tests pass (some warnings OK)

### Test 2: End-to-End Student Workflow

1. **Deploy student stack**:
   - Open landing page URL
   - Click "Deploy My Environment"
   - Use Neptun Code: `TEST01`
   - Select `task-01`
   - Create stack

2. **SSH to student instance**:
   ```bash
   ssh -i ~/.ssh/vockey.pem ubuntu@<PUBLIC_IP>
   ```

3. **Verify environment**:
   ```bash
   cat ~/welcome.txt
   kubectl get nodes
   kubectl get pods -n kyverno
   ls ~/student-tools/
   ls ~/k8s-workspace/tasks/task-01/
   ```

4. **Complete task**:
   ```bash
   cd ~/k8s-workspace/tasks/task-01
   cat README.md
   # Create solution.yaml
   kubectl apply -f solution.yaml
   ```

5. **Request evaluation**:
   ```bash
   ~/student-tools/request-evaluation.sh task-01
   ```

6. **Submit final**:
   ```bash
   ~/student-tools/submit-final.sh task-01
   ```

7. **View results (instructor side)**:
   ```bash
   cd instructor-tools
   ./view-results.sh
   ```

---

## Common Issues and Fixes

### Issue 1: Lambda 502 Error

**Symptom**: Evaluation returns HTTP 502 Bad Gateway

**Cause**: Lambda missing Python dependencies (PyYAML, requests)

**Fix**: Redeploy with dependencies
```bash
cd instructor-tools
./deploy-complete-setup.sh
```

The script will update existing Lambda functions with proper dependencies.

### Issue 2: Template Upload Issues

**Symptom**: CloudFormation shows old endpoints

**Cause**: Template not properly uploaded to S3

**Fix**: Re-upload template
```bash
cd instructor-tools
./reupload-template.sh
```

Requires endpoint files (EVALUATION_ENDPOINT.txt, etc.) to exist.

### Issue 3: AWS Learner Lab Session Expired

**Symptom**: Lambda functions disappeared, S3 buckets empty

**Cause**: AWS Learner Lab sessions expire every 4 hours

**Fix**: Complete redeployment
```bash
# Start new Learner Lab session
# Configure AWS CLI with new credentials
cd instructor-tools
./deploy-complete-setup.sh
```

All resources will be recreated. Share new landing page URL with students.

### Issue 4: Student Tools Not Created

**Symptom**: Student EC2 missing `~/student-tools/` or `~/k8s-workspace/`

**Cause**: UserData script failed during EC2 initialization

**Fix**: Check CloudFormation template is latest version
```bash
# Verify template was uploaded
aws s3 ls s3://k8s-assessment-templates/unified-student-template.yaml

# If needed, re-upload
cd instructor-tools
./reupload-template.sh

# Student must DELETE and RECREATE stack
```

**Debug**: Check UserData logs on student EC2:
```bash
sudo cat /var/log/user-data.log
```

### Issue 5: API Key Authentication Not Working

**Symptom**: Evaluation works without API key

**Cause**: Lambda environment variable not set

**Fix**: Update Lambda environment variables
```bash
cd instructor-tools
./deploy-complete-setup.sh
```

Check Lambda has API_KEY environment variable:
```bash
aws lambda get-function-configuration --function-name k8s-evaluation-function --query 'Environment.Variables.API_KEY'
```

---

## Viewing Student Results

### Quick View

```bash
cd instructor-tools
./view-results.sh
```

### Manual S3 Check

**Evaluations**:
```bash
aws s3 ls s3://k8s-eval-results/evaluations/ --recursive
```

**Submissions**:
```bash
aws s3 ls s3://k8s-eval-results/submissions/ --recursive
```

**Download specific result**:
```bash
aws s3 cp s3://k8s-eval-results/submissions/task-01/TEST01/final-submission.json .
cat final-submission.json | jq '.'
```

---

## Modifying Tasks

Tasks are defined in the CloudFormation template at:
- Line 97-109: Task metadata (names, descriptions)
- Line 333-416: Task README content

To add a new task:

1. Edit `cloudformation/unified-student-template.yaml`
2. Add to `TaskConfiguration` mapping:
   ```yaml
   task-04:
     Name: "Your Task Name"
     Description: "Task description"
     GitHubPath: "tasks/task-04"
   ```
3. Add to `TaskSelection` allowed values:
   ```yaml
   AllowedValues:
     - task-01
     - task-02
     - task-03
     - task-04  # Add new
   ```
4. Update task README in UserData section
5. Redeploy:
   ```bash
   cd instructor-tools
   ./reupload-template.sh
   ```

---

## Security Considerations

### API Key
- Randomly generated 32-character hex string
- Stored in Lambda environment variables
- Checked on every request
- Saved locally in `API_KEY.txt` (chmod 600)

### S3 Buckets
- **Templates bucket**: Publicly readable (required for CloudFormation)
- **Results bucket**: Private, only instructor access

### Lambda Function URLs
- Publicly accessible (auth-type: NONE)
- API key checked in application code
- Required for AWS Learner Lab (no IAM permissions)

### Student Clusters
- Service account with cluster-admin (required for evaluation)
- K3s uses self-signed certificates
- Publicly accessible on port 6443
- Auto-shutdown after 4 hours

---

## Resource Limits (AWS Learner Lab)

- **EC2**: t3.medium (2 vCPU, 4 GB RAM)
- **Lambda**: 512 MB memory, 300s timeout
- **S3**: Unlimited storage
- **Session**: 4 hours (then resources deleted)
- **Budget**: $50 total per learner

Students must complete work within session limits.

---

## Troubleshooting Checklist

Before reaching out for help:

- [ ] Ran `./check-prerequisites.sh` successfully
- [ ] Ran `./deploy-complete-setup.sh` without errors
- [ ] Ran `./test-complete-deployment.sh` - most tests pass
- [ ] Verified landing page accessible in browser
- [ ] Checked endpoint files exist (EVALUATION_ENDPOINT.txt, etc.)
- [ ] Verified AWS Learner Lab session is active
- [ ] Checked Lambda functions exist in AWS console
- [ ] Verified S3 buckets created and accessible
- [ ] Tested template validation: `aws cloudformation validate-template --template-body file://unified-student-template.yaml`

---

## Redeployment After Session Expires

AWS Learner Lab sessions expire after 4 hours. To redeploy:

1. **Start new AWS Learner Lab session**
2. **Configure AWS CLI**:
   ```bash
   aws configure
   # Or use temporary credentials from Learner Lab
   ```
3. **Redeploy everything**:
   ```bash
   cd instructor-tools
   ./deploy-complete-setup.sh
   ```
4. **Share NEW landing page URL** with students
   (S3 bucket URLs remain the same, but Lambda endpoints change)

**Note**: Old student stacks will fail. Students must:
- Delete their old CloudFormation stack
- Deploy new stack from updated template

---

## Best Practices

### For Instructors:
1. ✅ Test the complete workflow yourself before assigning to students
2. ✅ Keep endpoint files (`*.txt`) backed up
3. ✅ Monitor S3 results bucket regularly
4. ✅ Set clear deadlines (account for 4-hour session limits)
5. ✅ Provide students with SSH key pair instructions
6. ✅ Have a backup plan for Learner Lab outages

### For Students:
1. ✅ Start early (4-hour session limit)
2. ✅ Save work regularly (copy YAML files locally)
3. ✅ Test evaluation before final submission
4. ✅ Use `kubectl get all` to verify resources
5. ✅ Read task README carefully
6. ✅ Don't wait until deadline (AWS issues happen)

---

## Support and Feedback

For issues:
1. Check `TROUBLESHOOTING.md` (if exists)
2. Review logs: `/var/log/user-data.log` on student EC2
3. Check Lambda CloudWatch logs
4. Test with known-good deployment (TEST01)

For feature requests:
- Create GitHub issue
- Include use case and requirements

---

## Version History

**v2.0** (Current)
- ✅ Unified deployment script
- ✅ Fixed Lambda dependency packaging
- ✅ Removed GitHub clone dependency
- ✅ Improved variable substitution in UserData
- ✅ Better error handling and testing

**v1.0** (Legacy)
- Multiple deployment scripts
- Manual dependency management
- GitHub repository dependency
- Scattered configuration

---

## Quick Reference Commands

```bash
# Deploy everything from scratch
./deploy-complete-setup.sh

# Test deployment
./test-complete-deployment.sh

# Re-upload template only
./reupload-template.sh

# View student results
./view-results.sh

# Check prerequisites
./check-prerequisites.sh

# View Lambda logs
aws logs tail /aws/lambda/k8s-evaluation-function --follow

# List student stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE

# Download all results
aws s3 sync s3://k8s-eval-results/submissions/ ./results/
```

---

**Ready to deploy!** 🚀

Run `./deploy-complete-setup.sh` from the `instructor-tools/` directory.
