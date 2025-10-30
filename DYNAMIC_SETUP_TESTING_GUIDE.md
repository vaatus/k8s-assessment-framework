# Dynamic Setup Testing Guide - Automated Image Deployment

Complete guide for testing the dynamic evaluation system with automated Docker image deployment.

## Overview

The dynamic setup now includes **fully automated Docker image deployment**:
- Images are built locally and uploaded to S3
- CloudFormation automatically downloads images during EC2 initialization
- Images are imported into K3s without any manual SSH access
- Students get pre-configured environments ready to use

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ INSTRUCTOR SETUP (One-time)                              │
├──────────────────────────────────────────────────────────┤
│ 1. Build Docker images locally                           │
│    • test-runner:latest                                  │
│    • kvstore:latest                                      │
│                                                           │
│ 2. Upload to S3                                          │
│    • s3://k8s-assessment-templates/docker-images/        │
│    • Publicly accessible                                 │
│                                                           │
│ 3. Deploy Lambda functions                               │
│    • evaluator_dynamic.py                                │
│    • submitter.py                                        │
│                                                           │
│ 4. Upload task specifications                            │
│    • task-01/task-spec.yaml                              │
│    • task-02/task-spec.yaml                              │
│    • task-03/task-spec.yaml                              │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ STUDENT DEPLOYMENT (Automated via CloudFormation)        │
├──────────────────────────────────────────────────────────┤
│ 1. EC2 instance launches                                 │
│                                                           │
│ 2. UserData script runs:                                 │
│    • Installs K3s                                        │
│    • Downloads test-runner.tar from S3                   │
│    • Downloads kvstore.tar from S3                       │
│    • Imports images into K3s                             │
│    • Creates task namespace                              │
│    • Configures evaluation tools                         │
│                                                           │
│ 3. Student environment ready:                            │
│    • K3s cluster with images pre-loaded                  │
│    • No manual configuration needed                      │
│    • Can immediately deploy solutions                    │
└──────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────┐
│ EVALUATION FLOW                                           │
├──────────────────────────────────────────────────────────┤
│ 1. Student runs request-evaluation.sh                    │
│                                                           │
│ 2. Lambda evaluator:                                     │
│    • Loads task spec from S3                             │
│    • Validates Kubernetes resources                      │
│    • Deploys test-runner pod (already available)         │
│    • Runs HTTP endpoint tests                            │
│    • Calculates score                                    │
│    • Stores results in S3                                │
└──────────────────────────────────────────────────────────┘
```

## Prerequisites

- **Docker**: Required to build images
- **AWS CLI**: Configured with valid credentials
- **Active AWS Learner Lab**: With sufficient quota
- **Git**: Repository cloned locally

## Complete Testing Steps

### Phase 1: Deploy Infrastructure

#### 1.1 Run Complete Setup Script

```bash
cd instructor-tools

# This will:
# - Create S3 buckets
# - Build and upload Docker images (if Docker is available)
# - Deploy Lambda functions with dynamic evaluator
# - Configure CloudFormation template
# - Generate student landing page

./deploy-complete-setup.sh
```

**Interactive Prompts:**

1. **Confirm deployment**: Type `yes`
2. **Build Docker images**: Type `yes` (or press Enter for default)
3. **Choose evaluator**: Type `2` for dynamic evaluator

**What Gets Created:**

✅ S3 buckets:
- `k8s-eval-results` (private)
- `k8s-assessment-templates` (public)

✅ Docker images uploaded to S3:
- `docker-images/test-runner.tar`
- `docker-images/kvstore.tar`

✅ Lambda functions:
- Evaluation Lambda (with `evaluator_dynamic.py`)
- Submission Lambda

✅ CloudFormation template:
- Auto-configured with Lambda endpoints
- Includes Docker image download logic

✅ Output files:
- `API_KEY.txt`
- `EVALUATION_ENDPOINT.txt`
- `SUBMISSION_ENDPOINT.txt`

#### 1.2 Upload Task Specifications

```bash
# Still in instructor-tools directory
./upload-task-specs.sh
```

This uploads task specs to:
- `s3://k8s-eval-results/task-specs/task-01/task-spec.yaml`
- `s3://k8s-eval-results/task-specs/task-02/task-spec.yaml`
- `s3://k8s-eval-results/task-specs/task-03/task-spec.yaml`

#### 1.3 Update Lambda Environment

```bash
# Configure Lambda to use local image names
API_KEY=$(cat API_KEY.txt)

aws lambda update-function-configuration \
  --function-name k8s-evaluation-function \
  --environment "Variables={S3_BUCKET=k8s-eval-results,API_KEY=${API_KEY},TEST_RUNNER_IMAGE=test-runner:latest}" \
  --region us-east-1

# Verify configuration
aws lambda get-function-configuration \
  --function-name k8s-evaluation-function \
  --region us-east-1 \
  --query 'Environment.Variables'
```

---

### Phase 2: Deploy Student Environment

#### 2.1 Get Landing Page URL

```bash
echo "Landing Page: https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html"
```

#### 2.2 Deploy Stack via AWS Console

1. Open the landing page URL in browser
2. Click "Deploy My Environment"
3. Sign in to AWS Learner Lab
4. In CloudFormation console, fill parameters:
   - **Stack name**: `k8s-student-TEST01`
   - **NeptunCode**: `TEST01` (6 characters)
   - **TaskSelection**: `task-02` (for testing dynamic features)
   - **KeyPairName**: Your AWS key pair (usually `vockey`)
5. Click "Create Stack"
6. Wait 5-10 minutes for completion

#### 2.3 Monitor Stack Creation

```bash
# Watch stack events
aws cloudformation describe-stack-events \
  --stack-name k8s-student-TEST01 \
  --region us-east-1 \
  --max-items 10 \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId]' \
  --output table

# Get stack status
aws cloudformation describe-stacks \
  --stack-name k8s-student-TEST01 \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus' \
  --output text
```

Wait for status: `CREATE_COMPLETE`

#### 2.4 Verify UserData Execution

```bash
# Get EC2 instance ID
INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --stack-name k8s-student-TEST01 \
  --region us-east-1 \
  --query 'StackResources[?ResourceType==`AWS::EC2::Instance`].PhysicalResourceId' \
  --output text)

echo "Instance ID: $INSTANCE_ID"

# Check UserData logs via CloudWatch (if enabled) or EC2 console
# The logs will show:
# - K3s installation
# - Downloading test-runner.tar from S3
# - Downloading kvstore.tar from S3
# - Importing images into K3s
# - ✅ test-runner:latest imported successfully
# - ✅ kvstore:latest imported successfully
```

---

### Phase 3: Test Task-02 (StatefulSet with Dynamic Evaluation)

#### 3.1 Get SSH Access

```bash
# Get EC2 public IP
EC2_IP=$(aws cloudformation describe-stacks \
  --stack-name k8s-student-TEST01 \
  --query 'Stacks[0].Outputs[?OutputKey==`EC2PublicIP`].OutputValue' \
  --output text \
  --region us-east-1)

echo "EC2 Public IP: $EC2_IP"

# SSH to instance
ssh -i ~/.ssh/vockey.pem ubuntu@$EC2_IP
```

#### 3.2 Verify Images Are Available

```bash
# Check images in K3s
sudo k3s ctr images ls | grep -E "test-runner|kvstore"

# Expected output:
# docker.io/library/kvstore:latest
# docker.io/library/test-runner:latest
```

✅ If images are present, the automated import worked!

#### 3.3 Verify Environment Setup

```bash
# Check K3s cluster
kubectl get nodes

# Check namespace
kubectl get namespace task-02

# Check workspace
ls -la ~/k8s-workspace/tasks/task-02/

# Read task instructions
cat ~/k8s-workspace/tasks/task-02/README.md
```

#### 3.4 Deploy Task-02 Solution

Create `~/k8s-workspace/tasks/task-02/solution.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: key-value-headless
  namespace: task-02
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: key-value
  ports:
    - port: 5000
      targetPort: 5000
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: key-value-svc
  namespace: task-02
spec:
  serviceName: key-value-headless
  replicas: 4
  selector:
    matchLabels:
      app: key-value
  template:
    metadata:
      labels:
        app: key-value
    spec:
      containers:
      - name: app
        image: kvstore:latest          # ← Local image, pre-imported
        imagePullPolicy: Never           # ← Don't pull from registry
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Mi
```

Apply the solution:

```bash
kubectl apply -f ~/k8s-workspace/tasks/task-02/solution.yaml

# Watch pods come up
kubectl get pods -n task-02 -w
```

Wait for all 4 pods: `Running` and `1/1 Ready`

#### 3.5 Manual Validation (Optional)

```bash
# Check all resources
kubectl get all,pvc -n task-02

# Test HTTP endpoints
kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-02 -- \
  curl -X POST -d "testvalue" http://key-value-svc-0.key-value-headless:5000/obj/testkey

# Should return success

kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-02 -- \
  curl http://key-value-svc-0.key-value-headless:5000/obj/testkey

# Should return: testvalue
```

#### 3.6 Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-02
```

**Expected Output:**

```
===========================================
Evaluation Results
===========================================
Student ID: TEST01
Task: task-02
Score: 80/100

Detailed Results:
✅ StatefulSet exists: 15/15 points
✅ Replica count correct (4): 10/10 points
✅ PVCs created: 15/15 points
✅ Headless service exists: 10/10 points
✅ All pods running: 10/10 points
✅ Store data (POST /obj/testkey): 10/10 points
✅ Retrieve data (GET /obj/testkey): 10/10 points
❌ Data persistence after restart: 0/20 points

eval_token: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Save this token for submission!
```

**What Happened Behind the Scenes:**

1. Script sent cluster credentials to Lambda
2. Lambda loaded `task-02/task-spec.yaml` from S3
3. Lambda validated StatefulSet, PVCs, Service, Pods
4. Lambda created test-runner pod in namespace `task-02`
5. Test-runner executed HTTP POST and GET checks
6. Lambda collected results and calculated score
7. Lambda stored evaluation in S3
8. Script displayed results

#### 3.7 Verify Test-Runner Execution

```bash
# Check if test-runner pod was created
kubectl get pods -n task-02 -l job-name=test-runner

# If still running, check logs
kubectl logs -l job-name=test-runner -n task-02

# Pod should auto-delete after completion
```

#### 3.8 Submit Final Results

```bash
~/student-tools/submit-final.sh task-02
```

---

### Phase 4: Instructor Verification

Exit SSH and return to local machine:

```bash
exit
```

#### 4.1 View Student Results

```bash
cd instructor-tools

# View all results
./view-results.sh

# Check S3 directly
aws s3 ls s3://k8s-eval-results/evaluations/TEST01/task-02/ --recursive
aws s3 ls s3://k8s-eval-results/submissions/TEST01/task-02/ --recursive
```

#### 4.2 Inspect Evaluation Details

```bash
# Get latest evaluation token
EVAL_TOKEN=$(aws s3 ls s3://k8s-eval-results/evaluations/TEST01/task-02/ | tail -1 | awk '{print $4}' | sed 's/.json//')

# Download and view evaluation
aws s3 cp s3://k8s-eval-results/evaluations/TEST01/task-02/${EVAL_TOKEN}.json - | jq .
```

#### 4.3 Check Lambda Logs

```bash
# Watch Lambda logs in real-time
aws logs tail /aws/lambda/k8s-evaluation-function --follow --region us-east-1

# Look for:
# - "Loading task specification for task-02"
# - "Downloading Docker images from S3..."
# - "✅ test-runner:latest imported successfully"
# - "Creating test-runner pod..."
# - "HTTP check: store_data - PASS"
# - "HTTP check: retrieve_data - PASS"
# - "Calculating score: 80/100"
```

---

## Troubleshooting

### Issue: Images Not Downloaded During Stack Creation

**Check UserData logs:**

```bash
# SSH to EC2
ssh -i ~/.ssh/vockey.pem ubuntu@$EC2_IP

# Check logs
cat /var/log/user-data.log | grep -A10 "Downloading Docker images"

# Should show:
# Downloading test-runner image...
# Downloading kvstore image...
# ✅ test-runner:latest imported successfully
# ✅ kvstore:latest imported successfully
```

**If images failed to download:**

```bash
# Check S3 bucket access
wget -q https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/docker-images/test-runner.tar -O /tmp/test.tar

# If fails: Images not uploaded to S3
# Solution: Run build-and-upload-images.sh manually
```

### Issue: Images Not Imported to K3s

```bash
# Check if tar files exist
ls -lh /tmp/*.tar

# Try manual import
sudo k3s ctr images import /tmp/test-runner.tar
sudo k3s ctr images import /tmp/kvstore.tar

# Verify import
sudo k3s ctr images ls | grep -E "test-runner|kvstore"
```

### Issue: ImagePullBackOff on Student Pods

**Symptoms:**

```bash
kubectl get pods -n task-02
# NAME              READY   STATUS             RESTARTS   AGE
# key-value-svc-0   0/1     ImagePullBackOff   0          30s
```

**Cause:** Missing `imagePullPolicy: Never` in YAML

**Solution:**

```bash
# Edit StatefulSet
kubectl edit statefulset key-value-svc -n task-02

# Add under containers:
spec:
  template:
    spec:
      containers:
      - name: app
        image: kvstore:latest
        imagePullPolicy: Never  # ← Add this line
```

### Issue: Test-Runner Pod Fails to Start

**Check Lambda logs:**

```bash
aws logs tail /aws/lambda/k8s-evaluation-function --follow --region us-east-1
```

**Look for errors like:**
- "Failed to create test-runner pod"
- "Image test-runner:latest not found"

**Solution:**

```bash
# Verify image exists in student cluster
ssh -i ~/.ssh/vockey.pem ubuntu@$EC2_IP
sudo k3s ctr images ls | grep test-runner

# If missing, re-import
wget -q https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/docker-images/test-runner.tar -O /tmp/test-runner.tar
sudo k3s ctr images import /tmp/test-runner.tar
```

---

## Updating Docker Images

If you need to update the Docker images after initial deployment:

### 1. Rebuild and Re-upload Images

```bash
cd instructor-tools

# This will rebuild and re-upload
./build-and-upload-images.sh
```

### 2. Update CloudFormation Template

```bash
# Re-upload the CloudFormation template
./reupload-template.sh
```

### 3. For Existing Student Stacks

Students need to:
1. Delete their existing stack
2. Deploy a new stack (which will download updated images)

Or manually update images on EC2:

```bash
# SSH to student EC2
ssh -i ~/.ssh/vockey.pem ubuntu@$EC2_IP

# Remove old image
sudo k3s ctr images rm docker.io/library/kvstore:latest

# Download and import new image
wget -q https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/docker-images/kvstore.tar -O /tmp/kvstore.tar
sudo k3s ctr images import /tmp/kvstore.tar

# Restart pods to use new image
kubectl delete pod -n task-02 -l app=key-value
```

---

## Success Criteria

Your dynamic setup is working correctly when:

1. ✅ Docker images build successfully
2. ✅ Images upload to S3 without errors
3. ✅ CloudFormation stack creates successfully
4. ✅ UserData logs show images downloaded and imported
5. ✅ `sudo k3s ctr images ls` shows test-runner and kvstore
6. ✅ Student pods start without ImagePullBackOff
7. ✅ Lambda creates test-runner pod successfully
8. ✅ HTTP endpoint tests execute and pass
9. ✅ Evaluation results stored in S3
10. ✅ Score calculated correctly based on task-spec.yaml

---

## Key Advantages of This Approach

### ✅ No Manual SSH Required
- Everything automated via CloudFormation
- Students get pre-configured environments
- No image transfer needed

### ✅ Consistent Environment
- All students get exact same images
- No version mismatches
- Reproducible deployments

### ✅ Easy Updates
- Update images in S3 once
- All new deployments use updated images
- Simple rollout process

### ✅ Scalable
- Supports multiple students
- No instructor intervention per student
- Fully automated workflow

### ✅ Offline-Capable
- Images downloaded during setup
- No external registry dependencies
- Works in restricted networks

---

## Next Steps

1. **Test Task-01**: Simple deployment (no HTTP testing)
2. **Test Task-03**: Multi-service with probes
3. **Add Custom Tasks**: Create new task specs
4. **Production Deployment**: Share landing page with students

---

## Quick Reference Commands

### Build and Upload Images
```bash
cd instructor-tools
./build-and-upload-images.sh
```

### Deploy Infrastructure
```bash
./deploy-complete-setup.sh
```

### Upload Task Specs
```bash
./upload-task-specs.sh
```

### View Student Results
```bash
./view-results.sh
```

### Check Lambda Logs
```bash
aws logs tail /aws/lambda/k8s-evaluation-function --follow --region us-east-1
```

### Verify Images in K3s (On Student EC2)
```bash
sudo k3s ctr images ls | grep -E "test-runner|kvstore"
```

---

**Status**: Dynamic Setup with Automated Image Deployment ✅

Last updated: 2025-10-30
