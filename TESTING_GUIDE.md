# Testing Guide - Remote Kubernetes Assessment Framework
## Step-by-Step Instructions for Full System Validation

This guide walks you through testing the complete remote evaluation workflow from instructor setup to student submission.

---

## Prerequisites

- ✅ Two AWS Learner Lab accounts (Instructor & Student) OR
- ✅ One AWS Learner Lab account for testing both roles
- ✅ EC2 key pair created in us-east-1 (usually `vockey`)
- ✅ This repository cloned in CloudShell

---

## Part 1: Instructor Setup (Account A)

### Step 1.1: Login to Instructor AWS Learner Lab

1. Open AWS Learner Lab
2. Click "Start Lab"
3. Wait for AWS indicator to turn green
4. Click "AWS" to open CloudShell

### Step 1.2: Clone Repository (if not already done)

```bash
# In CloudShell
cd ~
git clone <your-repo-url> k8s-assessment-framework
# OR if already cloned
cd ~/k8s-assessment-framework
git pull
```

### Step 1.3: Deploy S3 Bucket

```bash
cd ~/k8s-assessment-framework/instructor-tools
chmod +x *.sh
./setup-s3-bucket.sh
```

**Expected Output:**
```
=== Setting up S3 Bucket for Evaluation Results ===
Creating S3 bucket: k8s-eval-results
✅ Bucket created successfully
Adding bucket policy...
✅ Bucket policy applied
Creating folder structure...
✅ Folders created: evaluations/, submissions/, tasks/
=== S3 Setup Complete ===
Bucket name: k8s-eval-results
```

**Verify:**
```bash
aws s3 ls s3://k8s-eval-results/
# Should show: evaluations/ submissions/ tasks/
```

### Step 1.4: Deploy Evaluation Lambda

```bash
./deploy-evaluation-lambda.sh
```

**Expected Output:**
```
=== Deploying Evaluation Lambda ===
Generating new API key...
✅ API key generated and saved to API_KEY.txt
Using Role ARN: arn:aws:iam::123456789012:role/LabRole
Creating deployment package...
Collecting PyYAML...
Collecting requests...
Successfully installed...
Creating new function...
✅ Function created
Creating Function URL...
✅ Function URL created: https://xxxxx.lambda-url.us-east-1.on.aws/
=== Deployment complete! ===
```

**Verify:**
```bash
# Check files created
ls -la API_KEY.txt EVALUATION_ENDPOINT.txt

# Check Lambda exists
aws lambda get-function --function-name k8s-task-evaluator --query 'Configuration.FunctionName'
```

### Step 1.5: Deploy Submission Lambda

```bash
./deploy-submission-lambda.sh
```

**Expected Output:**
```
=== Deploying Submission Handler Lambda ===
✅ Using API key from API_KEY.txt
Using Role ARN: arn:aws:iam::123456789012:role/LabRole
Creating deployment package...
Creating new function...
✅ Function created
Creating Function URL...
✅ Function URL created: https://yyyyy.lambda-url.us-east-1.on.aws/
=== Deployment complete! ===
```

### Step 1.6: Test Complete Setup

```bash
./test-complete-setup.sh
```

**Expected Output:**
```
=== Testing Complete Setup ===
1. Checking S3 bucket...
✅ S3 bucket accessible

2. Checking Evaluation Lambda...
✅ Evaluation Lambda exists
✅ Evaluation URL: https://xxxxx.lambda-url.us-east-1.on.aws/

3. Checking Submission Lambda...
✅ Submission Lambda exists
✅ Submission URL: https://yyyyy.lambda-url.us-east-1.on.aws/

4. Testing Lambda connectivity...
✅ Evaluation Lambda responding correctly (with API key authentication)

=== Setup Test Complete ===

🎯 Ready for quick deploy link creation!
Next step: cd ../cloudformation && ./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/API_KEY.txt)" \
  "vockey"
```

**If you see errors:**
- Check AWS credentials are active (`aws sts get-caller-identity`)
- Verify LabRole exists (`aws iam get-role --role-name LabRole`)
- Ensure region is us-east-1

### Step 1.7: Create Student Deployment Link

```bash
cd ../cloudformation
chmod +x *.sh

# Create quick-deploy link
./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/API_KEY.txt)" \
  "vockey"
```

**Expected Output:**
```
=== Creating CloudFormation Quick Deploy Link ===
Configuration:
  Evaluation Endpoint: https://xxxxx.lambda-url.us-east-1.on.aws/
  Submission Endpoint: https://yyyyy.lambda-url.us-east-1.on.aws/
  API Key: 1a2b3c4d... (hidden)
  Default Key Pair: vockey

Setting up S3 bucket for template hosting...
✅ Bucket k8s-assessment-templates already exists
Updating template with instructor endpoints...
Uploading template to S3...
✅ Template uploaded

=== Quick Deploy Link Created! ===

📋 Template URL:
   https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/student-quick-deploy.yaml

🚀 Quick Deploy Link:
   https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/student-quick-deploy.yaml&stackName=k8s-student-environment

📱 Student Access Page:
   https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html

✅ Quick Deploy Link Setup Complete!
```

**Save the Quick Deploy Link** - you'll need it for student deployment!

---

## Part 2: Student Environment Deployment

### Step 2.1: Open CloudFormation Quick Deploy Link

**Option A: Same AWS Account Testing**
- Open the Quick Deploy Link in a new tab (stay logged in)

**Option B: Separate Student Account**
- Logout from instructor account
- Login to student AWS Learner Lab
- Open the Quick Deploy Link

### Step 2.2: Configure Stack Parameters

In the CloudFormation console:

1. **Stack name**: `k8s-student-environment` (pre-filled)
2. **Parameters:**
   - **Neptun Code**: Enter `TEST01` (or your 6-char code)
   - **Task Selection**: Select `task-01`
   - **Instance Type**: Keep default `t3.medium`
   - **Key Pair**: Keep default `vockey`
   - **Evaluation Endpoint**: Pre-filled (do not change)
   - **Submission Endpoint**: Pre-filled (do not change)
   - **API Key**: Pre-filled and hidden (do not change)

3. **Acknowledgments:**
   - ✅ Check "I acknowledge that AWS CloudFormation might create IAM resources"

4. Click **"Create stack"**

### Step 2.3: Wait for Stack Creation

**Timeline:** ~5-10 minutes

**Monitor Progress:**
- **Events Tab**: Watch resource creation
- **Resources Tab**: See what's being created
- **Outputs Tab**: Will show connection details when complete

**Look for:**
```
CREATE_IN_PROGRESS  StudentSecurityGroup
CREATE_COMPLETE     StudentSecurityGroup
CREATE_IN_PROGRESS  StudentInstanceRole
CREATE_COMPLETE     StudentInstanceRole
CREATE_IN_PROGRESS  StudentInstanceProfile
CREATE_COMPLETE     StudentInstanceProfile
CREATE_IN_PROGRESS  StudentK3sInstance
CREATE_COMPLETE     StudentK3sInstance
CREATE_COMPLETE     k8s-student-environment
```

**Stack Status:** `CREATE_COMPLETE` ✅

### Step 2.4: Get Connection Details

Click **Outputs** tab:

| Key | Value |
|-----|-------|
| PublicIP | 54.123.45.67 |
| ConnectionDetails | ssh -i vockey.pem ubuntu@54.123.45.67 |
| KubernetesEndpoint | https://54.123.45.67:6443 |
| TaskAssignment | task-01: Deploy NGINX Web Application |

**Copy the SSH command**

---

## Part 3: Student Task Completion

### Step 3.1: Connect via SSH

**Download vockey.pem** (if not already done):
- In Learner Lab, click "AWS Details"
- Click "Download PEM"
- Save to your local machine

**Connect:**
```bash
chmod 400 vockey.pem
ssh -i vockey.pem ubuntu@54.123.45.67
```

**You should see:**
```
============================================
🎓 Welcome TEST01!
============================================

Your Kubernetes environment is ready!

📁 Workspace: /home/ubuntu/k8s-workspace
📋 Your Task: task-01
🔍 Task Description: Deploy NGINX Web Application

📚 Quick Start:
1. cd k8s-workspace
2. cat tasks/task-01/README.md
3. Create your solution
4. ./student-tools/request-evaluation.sh task-01
5. ./student-tools/submit-final.sh task-01

💡 Tips:
- Check cluster status: kubectl get nodes
- View your namespace: kubectl get all -n task-01
- Need help? Read the task README file

Good luck with your assessment! 🚀
============================================
```

### Step 3.2: Verify Environment

```bash
# Check cluster is running
kubectl get nodes

# Expected output:
# NAME   STATUS   ROLES                  AGE   VERSION
# ip-... Ready    control-plane,master   5m    v1.27.x

# Check task namespace exists
kubectl get ns task-01

# Check workspace structure
cd k8s-workspace
ls -la
# Should show: tasks/ student-tools/ EVALUATION_ENDPOINT.txt etc.
```

### Step 3.3: Read Task Requirements

```bash
cat tasks/task-01/README.md
```

**Requirements:**
- Deployment name: `nginx-web`
- Namespace: `task-01`
- Replicas: `3`
- Image: `nginx:1.25`
- Resource limits: CPU 100m, Memory 128Mi
- Resource requests: CPU 50m, Memory 64Mi
- Label: `app=nginx-web`
- All pods Running

### Step 3.4: Create Solution

```bash
# Create deployment manifest
cat > nginx-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  namespace: task-01
  labels:
    app: nginx-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-web
  template:
    metadata:
      labels:
        app: nginx-web
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
        ports:
        - containerPort: 80
EOF

# Deploy it
kubectl apply -f nginx-deployment.yaml
```

**Expected:**
```
deployment.apps/nginx-web created
```

### Step 3.5: Verify Deployment

```bash
# Check deployment
kubectl get deployment -n task-01

# Expected:
# NAME        READY   UP-TO-DATE   AVAILABLE   AGE
# nginx-web   3/3     3            3           30s

# Check pods
kubectl get pods -n task-01

# Expected: 3 pods in Running state
# NAME                         READY   STATUS    RESTARTS   AGE
# nginx-web-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
# nginx-web-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
# nginx-web-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# Detailed check
kubectl describe deployment nginx-web -n task-01
```

---

## Part 4: Remote Evaluation (THE KEY FEATURE!)

### Step 4.1: Request Evaluation

```bash
cd ~/k8s-workspace/student-tools
./request-evaluation.sh task-01
```

**What Happens:**
1. Script reads configuration files
2. Gathers cluster credentials
3. Creates JSON payload
4. **Sends HTTPS request to instructor Lambda** (REMOTE!)
5. Lambda connects back to student cluster
6. Lambda evaluates deployment
7. Lambda calculates score
8. Lambda stores results in S3
9. Response returned to student

**Expected Output:**
```
=== Kubernetes Task Evaluation Request ===
Student ID: TEST01
Task ID: task-01
Namespace: task-01
Getting cluster information...
Using saved cluster credentials...
Cluster Endpoint: https://54.123.45.67:6443

Requesting evaluation...

=== EVALUATION RESULTS ===
{
  "eval_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "score": 100,
  "max_score": 100,
  "message": "Evaluation completed. Review results and submit if satisfied.",
  "results_summary": {
    "deployment_exists": true,
    "replicas_correct": true,
    "image_correct": true,
    "resources_set": true,
    "pods_running": true
  }
}

Evaluation token saved to: eval-token-task-01.txt
Use this token to submit your final results when satisfied

=== EVALUATION COMPLETE ===
```

### Step 4.2: Verify Token Saved

```bash
cat eval-token-task-01.txt
# Should show: a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

### Step 4.3: Test with Incorrect Solution (Optional)

```bash
# Modify deployment to have wrong replicas
kubectl scale deployment nginx-web -n task-01 --replicas=2

# Request evaluation again
./request-evaluation.sh task-01
```

**Expected: Lower score**
```json
{
  "score": 85,
  "results_summary": {
    "deployment_exists": true,
    "replicas_correct": false,  // ❌
    "image_correct": true,
    "resources_set": true,
    "pods_running": false       // ❌
  }
}
```

```bash
# Fix it back
kubectl scale deployment nginx-web -n task-01 --replicas=3
./request-evaluation.sh task-01
# Should get 100 again
```

---

## Part 5: Final Submission

### Step 5.1: Submit When Satisfied

```bash
./submit-final.sh task-01
```

**Confirmation Prompt:**
```
=== Final Task Submission ===
Student ID: TEST01
Task ID: task-01
Evaluation Token: a1b2c3d4-e5f6-7890-abcd-ef1234567890

WARNING: This will submit your final results for grading.
Make sure you have:
1. Completed the task requirements
2. Run request-evaluation.sh and reviewed the results
3. Made any necessary corrections

Are you sure you want to submit? (yes/no):
```

**Type:** `yes`

**Expected Output:**
```
Submitting final results...

=== SUBMISSION RESULTS ===
{
  "message": "Submission successful",
  "submission_id": "2025-10-21T14:30:00.123456",
  "score": 100,
  "max_score": 100,
  "task_id": "task-01"
}

✅ SUBMISSION SUCCESSFUL!
Evaluation token cleaned up

=== SUBMISSION COMPLETE ===
```

### Step 5.2: Verify Token Cleaned Up

```bash
ls -la eval-token-task-01.txt
# Should show: No such file or directory
```

---

## Part 6: Instructor Verification (Back to Account A)

### Step 6.1: Switch Back to Instructor Account

**If testing with separate accounts:**
- Logout from student account
- Login to instructor AWS Learner Lab
- Open CloudShell

**If same account:**
- Open new CloudShell tab

### Step 6.2: Check S3 for Results

```bash
# List all evaluations for TEST01
aws s3 ls s3://k8s-eval-results/evaluations/TEST01/task-01/

# Expected: Multiple evaluation files (one per evaluation request)
# 2025-10-21 14:25:00   1234 a1b2c3d4-e5f6-7890-abcd-ef1234567890.json
# 2025-10-21 14:28:00   1234 f9e8d7c6-b5a4-3210-9876-543210fedcba.json

# List submission
aws s3 ls s3://k8s-eval-results/submissions/task-01/TEST01/

# Expected: One submission file
# 2025-10-21 14:30:00   1456 2025-10-21T14:30:00.123456.json
```

### Step 6.3: Download and View Submission

```bash
# Download submission
aws s3 cp s3://k8s-eval-results/submissions/task-01/TEST01/2025-10-21T14:30:00.123456.json - | jq '.'
```

**Expected Output:**
```json
{
  "eval_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "student_id": "TEST01",
  "task_id": "task-01",
  "timestamp": "2025-10-21T14:28:00.123456",
  "submission_timestamp": "2025-10-21T14:30:00.123456",
  "score": 100,
  "max_score": 100,
  "results": {
    "deployment_exists": true,
    "replicas_correct": true,
    "image_correct": true,
    "resources_set": true,
    "labels_correct": true,
    "pods_running": true,
    "pod_count_correct": true
  },
  "status": "completed",
  "submitted": true
}
```

### Step 6.4: Download All Submissions for Grading

```bash
# Create local directory
mkdir -p ~/grading/task-01

# Download all submissions
aws s3 sync s3://k8s-eval-results/submissions/task-01/ ~/grading/task-01/

# View all scores
for file in ~/grading/task-01/*/*.json; do
  echo "Student: $(jq -r '.student_id' $file) - Score: $(jq -r '.score' $file)/$(jq -r '.max_score' $file)"
done

# Expected:
# Student: TEST01 - Score: 100/100
```

---

## Verification Checklist

### ✅ Instructor Setup
- [ ] S3 bucket created: `k8s-eval-results`
- [ ] Evaluation Lambda deployed and responding
- [ ] Submission Lambda deployed and responding
- [ ] API key generated and saved
- [ ] CloudFormation template uploaded to S3
- [ ] Quick deploy link created

### ✅ Student Deployment
- [ ] CloudFormation stack created successfully
- [ ] EC2 instance running
- [ ] K3s cluster initialized
- [ ] Task namespace created
- [ ] Student tools configured
- [ ] Configuration files present

### ✅ Task Completion
- [ ] NGINX deployment created correctly
- [ ] 3 replicas running
- [ ] Resource limits configured
- [ ] Labels applied correctly

### ✅ Remote Evaluation
- [ ] Evaluation request sent successfully
- [ ] Lambda connected to student cluster (REMOTE!)
- [ ] Evaluation completed
- [ ] Score calculated correctly
- [ ] Results stored in S3
- [ ] Evaluation token saved locally

### ✅ Submission
- [ ] Submission sent successfully
- [ ] Submission stored in S3
- [ ] Confirmation received
- [ ] Token file cleaned up

### ✅ Instructor Verification
- [ ] Submissions visible in S3
- [ ] Submission data complete and accurate
- [ ] Scores match expected results

---

## Troubleshooting

### Issue: "Evaluation Lambda not responding"

**Check:**
```bash
# Verify Lambda exists
aws lambda get-function --function-name k8s-task-evaluator

# Check Function URL
aws lambda get-function-url-config --function-name k8s-task-evaluator

# Test directly
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $(cat ~/k8s-assessment-framework/instructor-tools/API_KEY.txt)" \
  -d '{"student_id": "TEST", "task_id": "test"}' \
  "$(cat ~/k8s-assessment-framework/instructor-tools/EVALUATION_ENDPOINT.txt)"
```

### Issue: "401 Unauthorized"

**Cause:** API key mismatch

**Fix:**
```bash
# Redeploy Lambdas to regenerate API key
cd ~/k8s-assessment-framework/instructor-tools
./deploy-evaluation-lambda.sh
./deploy-submission-lambda.sh

# Recreate CloudFormation template with new API key
cd ../cloudformation
./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/API_KEY.txt)" \
  "vockey"
```

### Issue: "Cannot connect to cluster"

**Check student side:**
```bash
# Verify cluster is running
kubectl get nodes

# Check cluster endpoint
cat ~/k8s-workspace/cluster-endpoint.txt
# Should have external IP, not 127.0.0.1

# Verify token exists
cat ~/k8s-workspace/cluster-token.txt
# Should have long base64 token

# Test from student side
kubectl get ns task-01
```

### Issue: "Namespace not found"

**Fix:**
```bash
# Create namespace
kubectl create namespace task-01

# Verify
kubectl get ns task-01
```

---

## Success Criteria

You have successfully tested the framework when:

1. ✅ Instructor infrastructure deploys without errors
2. ✅ Student CloudFormation stack creates successfully
3. ✅ Student can SSH into EC2 instance
4. ✅ K3s cluster is running and accessible
5. ✅ **Remote evaluation request reaches instructor Lambda**
6. ✅ **Lambda successfully connects back to student cluster**
7. ✅ Evaluation scores deployment correctly
8. ✅ Results stored in instructor S3 bucket
9. ✅ Submission processed and recorded
10. ✅ Instructor can retrieve all submissions for grading

**The key achievement:** Lambda function in instructor AWS account remotely evaluates a Kubernetes cluster running in a separate student AWS account!

---

## Next Steps

After successful testing:

1. **Document results** for thesis
2. **Create additional tasks** (task-02, task-03)
3. **Design web UI** for student/instructor dashboards
4. **Enhance authentication** (per-student tokens)
5. **Add monitoring** (CloudWatch metrics)
6. **Implement CI/CD** for Lambda updates
