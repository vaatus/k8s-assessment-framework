# Full Setup and Testing Guide

Complete end-to-end guide for deploying and testing the Kubernetes Assessment Framework.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Infrastructure Deployment (Instructor)](#phase-1-infrastructure-deployment-instructor)
3. [Phase 2: Student Environment Deployment](#phase-2-student-environment-deployment)
4. [Phase 3: Student Workflow Testing](#phase-3-student-workflow-testing)
5. [Phase 4: Instructor Result Verification](#phase-4-instructor-result-verification)
6. [Phase 5: Cleanup](#phase-5-cleanup)
7. [Common Issues](#common-issues)

---

## Prerequisites

### Instructor AWS Account

- Active AWS Learner Lab session (or standard AWS account)
- AWS CLI installed and configured
- Python 3.x installed
- `jq` installed (optional but recommended for JSON formatting)

**Verify prerequisites:**
```bash
cd instructor-tools
./check-prerequisites.sh
```

### Student AWS Accounts

- Each student needs their own AWS Learner Lab account
- SSH key pair created (usually `vockey`)
- Unique 6-character Neptun Code (e.g., TEST01, TEST02)

---

## Phase 1: Infrastructure Deployment (Instructor)

### Step 1.1: Clone Repository

```bash
git clone <repository-url>
cd k8s-assessment-framework
```

### Step 1.2: Deploy Complete Infrastructure

```bash
cd instructor-tools
./deploy-complete-setup.sh
```

**Expected output:**
```
🚀 Starting Complete K8s Assessment Framework Deployment...

✅ S3 buckets configured
✅ Evaluation Lambda deployed
✅ Submission Lambda deployed
✅ Template uploaded to S3
✅ Landing page created

📋 Deployment Summary:
  - Evaluation Endpoint: https://xxxxx.lambda-url.us-east-1.on.aws/
  - Submission Endpoint: https://xxxxx.lambda-url.us-east-1.on.aws/
  - API Key: (saved to API_KEY.txt)
  - Landing Page: https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html

✅ Deployment complete!
```

**Duration**: 3-5 minutes

### Step 1.3: Verify Deployment

```bash
./test-complete-deployment.sh
```

**Expected output:**
```
✅ AWS credentials valid
✅ S3 results bucket exists
✅ S3 templates bucket exists
✅ Evaluation Lambda deployed
✅ Submission Lambda deployed
✅ Evaluation endpoint accessible
✅ Submission endpoint accessible
✅ Template uploaded and accessible
✅ Landing page accessible
```

Some warnings about API key authentication are OK (the test can be flaky).

### Step 1.4: Save Critical Files

Three files created in `instructor-tools/`:
- `EVALUATION_ENDPOINT.txt` - Evaluation Lambda URL
- `SUBMISSION_ENDPOINT.txt` - Submission Lambda URL
- `API_KEY.txt` - Authentication key (chmod 600)

**⚠️ IMPORTANT**: Keep these files safe! They are needed for:
- Redeploying after AWS Learner Lab session expires
- Template updates with `./reupload-template.sh`

### Step 1.5: Share Landing Page

Copy the landing page URL from deployment output:
```
https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html
```

Share this URL with students via email, LMS, or course website.

---

## Phase 2: Student Environment Deployment

### Step 2.1: Access Landing Page

Students visit the landing page URL and see:
- Framework description
- "Deploy My Environment" button

### Step 2.2: Deploy CloudFormation Stack

1. Click **"Deploy My Environment"**
2. Sign in to AWS Learner Lab account
3. CloudFormation console opens with pre-filled template

**Stack Parameters:**
- **Stack name**: k8s-student (default, can customize)
- **Neptun Code**: Enter unique code (e.g., TEST01)
- **Task Selection**: Choose assigned task (task-01, task-02, or task-03)
- **Key Pair**: Select vockey (or your SSH key)
- **Instance Type**: t3.medium (default, recommended)

4. Click **Next** → **Next** → **Create stack**

**Duration**: 5-10 minutes

### Step 2.3: Wait for Stack Creation

Monitor CloudFormation console:
- Status: `CREATE_IN_PROGRESS` → `CREATE_COMPLETE`
- Check **Events** tab if errors occur

**Common creation time:**
- VPC and networking: 1-2 minutes
- EC2 instance: 2-3 minutes
- K3s installation: 2-3 minutes
- Kyverno installation: 1-2 minutes

### Step 2.4: Get SSH Connection Info

Once stack shows `CREATE_COMPLETE`:

1. Go to **Outputs** tab
2. Copy **SSHCommand** value:
   ```bash
   ssh -i ~/.ssh/vockey.pem ubuntu@<PUBLIC_IP>
   ```
3. Copy **PublicIP** if needed

---

## Phase 3: Student Workflow Testing

### Step 3.1: SSH to Student EC2

```bash
ssh -i ~/.ssh/vockey.pem ubuntu@<PUBLIC_IP>
```

**First login** takes ~30 seconds as UserData script completes.

### Step 3.2: Verify Environment Setup

#### Check Welcome Message
```bash
cat ~/welcome.txt
```

**Expected output:**
```
================================================
  Kubernetes Assessment Environment
================================================

Student: TEST01
Task: task-01

Your K3s cluster is ready!

Quick Commands:
  kubectl get nodes
  kubectl get pods -n kyverno
  kubectl get all -n task-01

Student Tools:
  ~/student-tools/request-evaluation.sh task-01
  ~/student-tools/submit-final.sh task-01

Task Workspace:
  ~/k8s-workspace/tasks/task-01/

Good luck! 🚀
================================================
```

#### Check K3s Cluster
```bash
kubectl get nodes
```

**Expected output:**
```
NAME               STATUS   ROLES                  AGE   VERSION
ip-10-0-1-xxx      Ready    control-plane,master   5m    v1.28.x+k3s1
```

#### Check Kyverno
```bash
kubectl get pods -n kyverno
```

**Expected output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-xxx          1/1     Running   0          4m
kyverno-background-controller-xxx         1/1     Running   0          4m
kyverno-cleanup-controller-xxx            1/1     Running   0          4m
kyverno-reports-controller-xxx            1/1     Running   0          4m
```

Some cleanup pods may have `ImagePullBackOff` - this is OK, non-critical.

#### Check Student Tools
```bash
ls -la ~/student-tools/
```

**Expected output:**
```
-rwxr-xr-x 1 ubuntu ubuntu  request-evaluation.sh
-rwxr-xr-x 1 ubuntu ubuntu  submit-final.sh
```

#### Check Task Workspace
```bash
ls -la ~/k8s-workspace/tasks/task-01/
cat ~/k8s-workspace/tasks/task-01/README.md
```

**Expected output:**
- README.md with complete task instructions

#### Check Cluster Info Saved
```bash
cat ~/.kube-assessment/cluster-info.json
```

**Expected output:**
```json
{
  "neptun_code": "TEST01",
  "task_id": "task-01",
  "kube_api": "https://44.xxx.xxx.xxx:6443",
  "kube_token": "eyJhbG...",
  "public_ip": "44.xxx.xxx.xxx"
}
```

#### Verify Evaluation Endpoint
```bash
head -30 ~/student-tools/request-evaluation.sh | grep -i "https://"
```

Should show **actual Lambda URL**, not `EVAL_ENDPOINT_PLACEHOLDER`.

### Step 3.3: Complete the Task

Navigate to task directory:
```bash
cd ~/k8s-workspace/tasks/task-01
cat README.md
```

Read the task requirements carefully.

#### Create Solution (Example for task-01)

```bash
cat > solution.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  namespace: task-01
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "500m"
            memory: "512Mi"
          requests:
            cpu: "250m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: task-01
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

#### Apply Solution

```bash
kubectl apply -f solution.yaml
```

**Expected output:**
```
deployment.apps/nginx-web created
service/nginx-service created
```

#### Verify Deployment

```bash
kubectl get all -n task-01
```

**Expected output:**
```
NAME                             READY   STATUS    RESTARTS   AGE
pod/nginx-web-xxx                1/1     Running   0          30s
pod/nginx-web-yyy                1/1     Running   0          30s

NAME                    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
service/nginx-service   NodePort   10.43.xxx.xxx   <none>        80:30080/TCP   30s

NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-web   2/2     2            2           30s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-web-xxx          2         2         2       30s
```

Wait until both pods show `Running` status.

### Step 3.4: Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-01
```

**Expected output:**
```
=== Requesting Evaluation for task-01 ===

Sending evaluation request...

{
  "eval_token": "a024715f-ae5b-4055-9de5-9fcbb4c307bb",
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

✅ Evaluation complete!
Results saved to: /home/ubuntu/evaluation-results-task-01-1729610761.json
```

**Score breakdown:**
- 100/100: Perfect solution with all criteria met
- 80/100: Missing resource limits OR labels
- 70/100: Missing both resource limits AND labels
- Lower: Missing replicas, pods not running, wrong image, etc.

The evaluation result is saved locally. Review it:
```bash
cat ~/evaluation-results-task-01-*.json | jq '.'
```

### Step 3.5: Submit Final Results

If satisfied with the score:

```bash
~/student-tools/submit-final.sh task-01
```

**Interactive prompt:**
```
=== Final Submission for task-01 ===

⚠️  WARNING: This will submit your FINAL results to the instructor.
    You can only submit once per task.

Are you sure? (yes/no):
```

Type `yes` and press Enter.

**Expected output:**
```
Running evaluation to get latest eval_token...

Evaluation token received: a024715f-ae5b-405...

Submitting final results...

{
  "message": "Submission successful",
  "submission_id": "2025-10-22T13:36:42.306254",
  "score": 100,
  "max_score": 100,
  "task_id": "task-01"
}

✅ Submission successful!
Your results have been submitted to the instructor.

Details:
  - Submission ID: 2025-10-22T13:36:42.306254
  - Score: 100/100
  - Task: task-01
```

**Note**: The script runs evaluation again to ensure latest results are submitted.

---

## Phase 4: Instructor Result Verification

### Step 4.1: View All Results

From instructor machine (AWS CloudShell):

```bash
cd instructor-tools
./view-results.sh
```

**Expected output:**
```
╔══════════════════════════════════════════════════════════════╗
║       Kubernetes Assessment - Student Results Viewer         ║
╚══════════════════════════════════════════════════════════════╝

📊 EVALUATION RESULTS
─────────────────────────────────────────────────────────────

Student: TEST01 | Task: task-01
  2025-10-22 13:02:39  022f5c0b-2a0e-42e8-86b8-9845c5797f31.json
  2025-10-22 13:36:41  a024715f-ae5b-4055-9de5-9fcbb4c307bb.json

📝 FINAL SUBMISSIONS
─────────────────────────────────────────────────────────────

Student: TEST01 | Task: task-01
  2025-10-22 13:02:49  2025-10-22T13:02:48.565613.json
  2025-10-22 13:36:43  2025-10-22T13:36:42.306254.json

✅ Total students with submissions: 1
```

### Step 4.2: Check S3 Structure

#### Evaluations
```bash
aws s3 ls s3://k8s-eval-results/evaluations/TEST01/ --recursive
```

**Expected structure:**
```
evaluations/TEST01/task-01/022f5c0b-2a0e-42e8-86b8-9845c5797f31.json
evaluations/TEST01/task-01/a024715f-ae5b-4055-9de5-9fcbb4c307bb.json
```

#### Submissions
```bash
aws s3 ls s3://k8s-eval-results/submissions/TEST01/ --recursive
```

**Expected structure:**
```
submissions/TEST01/task-01/2025-10-22T13:02:48.565613.json
submissions/TEST01/task-01/2025-10-22T13:36:42.306254.json
```

### Step 4.3: Download and Review Submission

```bash
# List submissions
aws s3 ls s3://k8s-eval-results/submissions/TEST01/task-01/

# Download latest submission
aws s3 cp s3://k8s-eval-results/submissions/TEST01/task-01/2025-10-22T13:36:42.306254.json .

# View with jq (formatted)
cat 2025-10-22T13:36:42.306254.json | jq '.'

# Or without jq
cat 2025-10-22T13:36:42.306254.json
```

**Expected JSON format:**
```json
{
  "eval_token": "a024715f-ae5b-4055-9de5-9fcbb4c307bb",
  "student_id": "TEST01",
  "task_id": "task-01",
  "timestamp": "2025-10-22T13:36:41.058775",
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
  "submission_timestamp": "2025-10-22T13:36:42.306254",
  "submitted": true
}
```

### Step 4.4: Download All Results

```bash
# Download all submissions for grading
aws s3 sync s3://k8s-eval-results/submissions/ ./grading-results/

# View directory structure
tree grading-results/
```

---

## Phase 5: Cleanup

### Student Side

Students should delete their CloudFormation stack when done:

1. Go to CloudFormation console
2. Select `k8s-student` stack
3. Click **Delete**
4. Confirm deletion

**Auto-shutdown**: Student EC2 instances automatically shut down after 4 hours via CloudWatch alarm (configured in template).

### Instructor Side

#### Delete Lambda Functions
```bash
aws lambda delete-function --function-name k8s-evaluation-function
aws lambda delete-function --function-name k8s-submission-function
```

#### Empty and Delete S3 Buckets
```bash
# Empty buckets first
aws s3 rm s3://k8s-eval-results --recursive
aws s3 rm s3://k8s-assessment-templates --recursive

# Delete buckets
aws s3 rb s3://k8s-eval-results
aws s3 rb s3://k8s-assessment-templates
```

#### Remove Local Files
```bash
cd instructor-tools
rm -f *.txt student-deploy-page.html
```

---

## Common Issues

### Issue 1: Lambda 502 Error

**Symptom**: Evaluation returns HTTP 502 Bad Gateway

**Cause**: Lambda missing Python dependencies

**Fix**:
```bash
cd instructor-tools
./deploy-complete-setup.sh
```

### Issue 2: API Key Mismatch

**Symptom**: HTTP 401 Unauthorized

**Cause**: API key in Lambda doesn't match student scripts

**Fix**: The deployment script now automatically reuses existing API key from `API_KEY.txt`. If you need to manually sync:
```bash
API_KEY=$(cat API_KEY.txt)
aws lambda update-function-configuration \
  --function-name k8s-evaluation-function \
  --environment "Variables={S3_BUCKET=k8s-eval-results,API_KEY=$API_KEY}"
```

### Issue 3: Student Tools Not Created

**Symptom**: Missing `~/student-tools/` or `~/k8s-workspace/`

**Cause**: UserData script failed during initialization

**Debug**:
```bash
# On student EC2
sudo cat /var/log/user-data.log
```

**Fix**: Template issue - students must delete and recreate stack after instructor uploads fixed template.

### Issue 4: Cluster Connection Failed

**Symptom**: "Cannot connect to student cluster"

**Possible causes:**
1. Security group doesn't allow port 6443
2. Cluster endpoint using 127.0.0.1 instead of public IP
3. Service account token expired or invalid

**Debug**:
```bash
# On student EC2
cat ~/.kube-assessment/cluster-info.json
# Verify kube_api uses public IP, not 127.0.0.1

# Test cluster access
kubectl get nodes
```

### Issue 5: Namespace Not Found

**Symptom**: "Namespace task-01 not found"

**Cause**: Student deployed to wrong namespace

**Fix**: Student must deploy to task-specific namespace:
```bash
# Check namespace exists
kubectl get namespace task-01

# If not, create it
kubectl create namespace task-01

# Redeploy solution to correct namespace
kubectl apply -f solution.yaml -n task-01
```

### Issue 6: Pods Not Running

**Symptom**: `pods_running: false` in evaluation

**Debug**:
```bash
# On student EC2
kubectl get pods -n task-01
kubectl describe pod <pod-name> -n task-01
```

**Common causes:**
- Image pull failure
- Insufficient resources
- Syntax error in YAML
- Wrong namespace

### Issue 7: AWS Learner Lab Session Expired

**Symptom**: Lambda functions disappeared, S3 buckets empty

**Cause**: Learner Lab sessions expire after 4 hours

**Fix**: Complete redeployment
```bash
# Start new Learner Lab session
# Configure AWS CLI with new credentials
cd instructor-tools
./deploy-complete-setup.sh

# Share new landing page URL with students
# Students must delete old stacks and redeploy
```

---

## Testing Checklist

Use this checklist to verify complete functionality:

### Instructor Infrastructure
- [ ] Prerequisites check passes
- [ ] `deploy-complete-setup.sh` completes without errors
- [ ] Three endpoint files created (EVALUATION_ENDPOINT.txt, SUBMISSION_ENDPOINT.txt, API_KEY.txt)
- [ ] `test-complete-deployment.sh` shows mostly green checks
- [ ] Landing page accessible in browser
- [ ] S3 buckets exist and have correct permissions

### Student Environment
- [ ] CloudFormation stack creates successfully (CREATE_COMPLETE)
- [ ] Can SSH to student EC2 instance
- [ ] `~/welcome.txt` exists with correct information
- [ ] K3s cluster running (`kubectl get nodes` works)
- [ ] Kyverno pods running in kyverno namespace
- [ ] Student tools exist and are executable
- [ ] Task workspace exists with README
- [ ] `~/.kube-assessment/cluster-info.json` has correct endpoints
- [ ] Evaluation script contains real Lambda URL (not placeholder)

### Evaluation Workflow
- [ ] Student can deploy Kubernetes resources
- [ ] Resources appear in correct namespace (`kubectl get all -n task-01`)
- [ ] `request-evaluation.sh` returns HTTP 200
- [ ] Evaluation JSON contains score and results
- [ ] Results file saved locally
- [ ] eval_token present in response

### Submission Workflow
- [ ] `submit-final.sh` runs evaluation first
- [ ] Submission prompts for confirmation
- [ ] Returns HTTP 200 with success message
- [ ] submission_id present in response

### Instructor Verification
- [ ] `view-results.sh` shows student results
- [ ] Evaluation files exist in S3: `evaluations/{student_id}/{task_id}/`
- [ ] Submission files exist in S3: `submissions/{student_id}/{task_id}/`
- [ ] Can download and parse submission JSON
- [ ] Submission JSON contains all expected fields
- [ ] Score matches student's deployment

---

## Success Criteria

The framework is working correctly when:

1. ✅ Instructor can deploy with one command
2. ✅ Landing page accessible to students
3. ✅ Student stacks create automatically without errors
4. ✅ Student environment has all tools and workspace ready
5. ✅ Evaluation endpoint returns accurate scores
6. ✅ Submission endpoint stores results in S3
7. ✅ Instructor can view and download all results
8. ✅ API key remains consistent across redeployments
9. ✅ S3 path structure is consistent

---

## Performance Benchmarks

Based on testing with AWS Learner Lab:

| Operation | Duration |
|-----------|----------|
| Instructor deployment | 3-5 minutes |
| Student stack creation | 5-10 minutes |
| K3s cluster ready | 2-3 minutes |
| Kyverno installation | 1-2 minutes |
| Evaluation request | 5-10 seconds |
| Submission request | 5-10 seconds |

---

## Next Steps After Testing

Once complete testing is successful:

1. **Document Issues**: Note any recurring problems for documentation
2. **Optimize Scoring**: Adjust point allocation based on task difficulty
3. **Add More Tasks**: Create task-02 and task-03 with different requirements
4. **Create Student Guide**: Write simplified instructions for students
5. **Prepare Demo**: Test presentation walkthrough
6. **Backup Configuration**: Save API_KEY.txt and endpoint files securely

---

**Framework Status**: Production Ready ✅

This guide covers the complete workflow from infrastructure deployment to result verification.
