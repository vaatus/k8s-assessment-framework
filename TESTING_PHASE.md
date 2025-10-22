# Testing Phase Summary

## Current Status: ✅ Ready for Testing

All critical fixes have been consolidated into the main deployment script. The framework is ready for end-to-end testing.

---

## What Has Been Fixed

### 1. ✅ Lambda 502 Error (Missing Dependencies)
**Issue**: Lambda returning HTTP 502 because PyYAML and requests were not packaged.

**Fix Location**: `instructor-tools/deploy-complete-setup.sh` lines 99-131
- Properly packages Python dependencies with pip install -t
- Creates Lambda zip with all required libraries
- Excludes boto3 (provided by Lambda runtime)

**Verification**:
```bash
# After deployment, test Lambda endpoint
curl -X POST <EVAL_ENDPOINT> -H "X-API-Key: <API_KEY>" -H "Content-Type: application/json" -d '{"test": true}'
# Should return validation error, not 502
```

### 2. ✅ CloudFormation Template Variable Substitution
**Issue**: Student scripts had hardcoded placeholders, endpoints not substituted.

**Fix Location**: `cloudformation/unified-student-template.yaml` lines 423-588
- Changed heredoc from `<<'EOF'` to `<<EOF` for variable expansion
- Properly escaped bash variables with `\\\$`
- CloudFormation variables `${EvaluationEndpoint}`, `${ApiKey}`, `${SubmissionEndpoint}` now substitute correctly

**Verification**:
```bash
# On student EC2 after stack creation
cat ~/student-tools/request-evaluation.sh | grep -i "https://"
# Should show actual Lambda URL, not placeholder
```

### 3. ✅ Removed GitHub Clone Dependency
**Issue**: UserData trying to clone from GitHub (may not exist/be public).

**Fix Location**: `cloudformation/unified-student-template.yaml` lines 328-418
- Task workspace created directly in UserData
- Task README written inline
- No external dependencies

**Verification**:
```bash
# On student EC2
ls ~/k8s-workspace/tasks/task-01/
cat ~/k8s-workspace/tasks/task-01/README.md
```

### 4. ✅ Consolidated Deployment
**Issue**: Multiple scripts for different scenarios, losing consistency.

**Fix**: Everything in ONE script: `deploy-complete-setup.sh`
- Single source of truth
- Handles both new deployments and updates
- Consistent behavior every time

**Verification**:
```bash
cd instructor-tools
./deploy-complete-setup.sh
# Should complete without errors
```

---

## Repository Structure (Clean)

```
k8s-assessment-framework/
├── cloudformation/
│   └── unified-student-template.yaml          # ✅ Fixed UserData, variable substitution
├── evaluation/
│   └── lambda/
│       ├── evaluator.py                       # ✅ Working Lambda
│       └── requirements.txt                   # ✅ Only PyYAML + requests
├── submission/
│   └── lambda/
│       └── submitter.py                       # ✅ Working Lambda
├── instructor-tools/
│   ├── deploy-complete-setup.sh               # ✅ ONE SCRIPT - SOURCE OF TRUTH
│   ├── test-complete-deployment.sh            # Testing
│   ├── reupload-template.sh                   # Quick template re-upload
│   ├── view-results.sh                        # View results
│   └── check-prerequisites.sh                 # Prerequisites
├── legacy-scripts/                            # Old scripts (archived)
├── INSTRUCTOR_GUIDE.md                        # ✅ Complete documentation
├── TESTING_PHASE.md                           # ✅ This file
└── DEPLOYMENT_FIXED.md                        # Previous fixes reference
```

**Removed**:
- `setup-student-tools.sh` (functionality in CloudFormation template)
- `upload-template-only.sh` (use `reupload-template.sh` instead)
- Other redundant helper scripts

---

## Testing Checklist

### Phase 1: Infrastructure Testing (Instructor Side)

From your **instructor machine** (NOT student EC2):

```bash
cd k8s-assessment-framework/instructor-tools

# 1. Check prerequisites
./check-prerequisites.sh

# 2. Deploy complete infrastructure (this is the SOURCE OF TRUTH)
./deploy-complete-setup.sh
# Duration: 3-5 minutes
# Creates: S3 buckets, Lambda functions, uploads template, creates landing page

# 3. Test deployment
./test-complete-deployment.sh
# Should see mostly green ✅
# A few warnings OK (e.g., API auth test can be flaky)

# 4. Verify endpoint files created
ls -la *.txt
# Should see:
# - EVALUATION_ENDPOINT.txt
# - SUBMISSION_ENDPOINT.txt
# - API_KEY.txt (should be chmod 600)
```

**Expected Result**: All infrastructure deployed, landing page accessible.

---

### Phase 2: Student Stack Deployment

From **student AWS account** (or use your instructor account for testing):

```bash
# 1. Open landing page URL (from deploy script output)
# Example: https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html

# 2. Click "Deploy My Environment"

# 3. In CloudFormation console:
#    - Neptun Code: TEST01
#    - Task: task-01
#    - Key Pair: vockey
#    - Instance Type: t3.medium (default)

# 4. Create stack
#    Duration: 5-10 minutes

# 5. Wait for CREATE_COMPLETE

# 6. Check Outputs tab for SSH command
```

**Expected Result**: Stack creates successfully, outputs show SSH command and public IP.

---

### Phase 3: Student Environment Verification

SSH to the student EC2 instance:

```bash
ssh -i ~/.ssh/vockey.pem ubuntu@<PUBLIC_IP>
```

Once connected, verify everything was created automatically:

```bash
# 1. Check welcome message exists
cat ~/welcome.txt
# Should show: Neptun code, task assignment, instructions

# 2. Verify K3s cluster running
kubectl get nodes
# Should show: 1 node, STATUS=Ready

# 3. Verify Kyverno installed
kubectl get pods -n kyverno
# Should show: 4 pods, all Running

# 4. Check student tools created
ls -la ~/student-tools/
# Should show:
# - request-evaluation.sh (executable)
# - submit-final.sh (executable)

# 5. Verify tools have real endpoints (not placeholders)
head -30 ~/student-tools/request-evaluation.sh | grep -i "https://"
# Should show actual Lambda URL

# 6. Check task workspace
ls -la ~/k8s-workspace/tasks/task-01/
# Should show: README.md

cat ~/k8s-workspace/tasks/task-01/README.md
# Should show: Complete task instructions

# 7. Verify cluster credentials stored
cat ~/.kube-assessment/cluster-info.json
# Should show: neptun_code, task_id, kube_api, kube_token, public_ip
```

**Expected Result**: All files exist, scripts have real endpoints, README is complete.

---

### Phase 4: Task Completion and Evaluation

On the student EC2 instance:

```bash
# 1. Navigate to task
cd ~/k8s-workspace/tasks/task-01

# 2. Read instructions
cat README.md

# 3. Create solution
cat > solution.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-web
  namespace: default
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
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: default
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF

# 4. Apply solution
kubectl apply -f solution.yaml

# 5. Verify deployment
kubectl get all
# Should show: deployment, replicaset, pods, service

# 6. Request evaluation
~/student-tools/request-evaluation.sh task-01
# Should show: HTTP 200, evaluation results in JSON format
# Result file saved: ~/evaluation-results-task-01-<timestamp>.json

# 7. Check evaluation result
ls -lt ~/ | grep evaluation-results
cat ~/evaluation-results-task-01-*.json | jq '.'
# Should show:
# - success: true
# - checks passed
# - eval_token (needed for submission)
```

**Expected Result**:
- Deployment succeeds
- Evaluation returns HTTP 200
- JSON response shows passed checks
- eval_token present

---

### Phase 5: Final Submission

On the student EC2 instance:

```bash
# 1. Submit final results
~/student-tools/submit-final.sh task-01
# Will ask: "Are you sure? (yes/no):"
# Type: yes

# Process:
# - Runs evaluation again to get eval_token
# - Submits eval_token to submission endpoint
# - Should show: HTTP 200, success message
```

**Expected Result**:
- HTTP 200 response
- "Submission successful!" message
- No errors

---

### Phase 6: Instructor Verification

From your **instructor machine**:

```bash
cd instructor-tools

# 1. View all results
./view-results.sh

# Should show:
# - Evaluations for TEST01/task-01
# - Submission for TEST01/task-01

# 2. Manual S3 check
aws s3 ls s3://k8s-eval-results/evaluations/TEST01/ --recursive
aws s3 ls s3://k8s-eval-results/submissions/task-01/TEST01/ --recursive

# 3. Download and view submission
aws s3 cp s3://k8s-eval-results/submissions/task-01/TEST01/final-submission.json .
cat final-submission.json | jq '.'

# Should show:
# - neptun_code: TEST01
# - task_id: task-01
# - timestamp
# - evaluation results
# - success: true
```

**Expected Result**: All student results visible in S3, submission JSON is complete.

---

## Known Issues (Non-Critical)

### 1. API Key Authentication Test (Flaky)
**Issue**: `test-complete-deployment.sh` sometimes reports "API key authentication response unclear"

**Status**: Not critical - authentication IS working, but Lambda response format varies

**Workaround**: Manually test by calling Lambda without API key:
```bash
curl -X POST <EVAL_ENDPOINT> -H "Content-Type: application/json" -d '{"test": true}'
# Should return 401 or "Unauthorized"
```

### 2. AWS Learner Lab Session Limits
**Issue**: Sessions expire after 4 hours, all resources deleted

**Status**: Expected behavior, documented

**Workaround**: Students must complete work within 4 hours, or redeploy

---

## Critical Success Criteria

Before considering this READY FOR PRODUCTION:

- [ ] `deploy-complete-setup.sh` completes without errors
- [ ] Landing page accessible in browser
- [ ] Student stack creates successfully (CREATE_COMPLETE)
- [ ] Student EC2 has all tools and workspace automatically
- [ ] `request-evaluation.sh` returns HTTP 200 with JSON
- [ ] `submit-final.sh` returns HTTP 200 with success message
- [ ] Instructor can view results with `view-results.sh`
- [ ] Evaluation results appear in S3
- [ ] Submission results appear in S3

---

## Next Steps

### For Testing Phase:
1. Run through complete checklist above with TEST01
2. Test with second student (TEST02) to verify multi-student support
3. Test different tasks (task-01, task-02, task-03)
4. Verify error handling (wrong deployment, missing resources)
5. Test re-deployment after Learner Lab session expires

### For Production:
1. Final review of all scripts
2. Update any remaining documentation
3. Create student quick-start guide
4. Prepare demo for presentation
5. Set up monitoring/logging if needed

### For GitHub:
1. Review all changes in working directory
2. Commit consolidated changes
3. Push to repository
4. Tag release version (v2.0)

---

## Commands Summary

### Instructor Side
```bash
# Full deployment
cd instructor-tools && ./deploy-complete-setup.sh

# Test deployment
./test-complete-deployment.sh

# View results
./view-results.sh

# Re-upload template only
./reupload-template.sh
```

### Student Side
```bash
# Request evaluation
~/student-tools/request-evaluation.sh task-01

# Submit final
~/student-tools/submit-final.sh task-01

# View cluster
kubectl get all
kubectl get pods -n kyverno
```

---

## Files to Commit

When ready to push to GitHub:

```bash
# Modified files (core fixes)
cloudformation/unified-student-template.yaml
evaluation/lambda/requirements.txt
instructor-tools/deploy-complete-setup.sh

# New documentation
INSTRUCTOR_GUIDE.md
TESTING_PHASE.md

# No changes needed (already good)
evaluation/lambda/evaluator.py
submission/lambda/submitter.py
instructor-tools/test-complete-deployment.sh
instructor-tools/view-results.sh
```

**Don't commit**:
- `*.txt` files (EVALUATION_ENDPOINT.txt, API_KEY.txt, etc.)
- `student-deploy-page.html` (generated)
- `/tmp/` files

---

## Current State

✅ **All fixes consolidated into deploy-complete-setup.sh**
✅ **CloudFormation template fixed for automatic setup**
✅ **Lambda dependencies properly packaged**
✅ **Documentation complete**
✅ **Ready for end-to-end testing**

**Next Action**: Run complete testing checklist with TEST01 deployment.

---

**Let's test!** 🚀
