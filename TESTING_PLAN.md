# 🧪 Comprehensive Testing Plan

This testing plan validates the entire Kubernetes Assessment Framework works correctly and handles all previously identified issues.

## 🎯 Testing Objectives

1. **Instructor Setup**: Verify S3 bucket and Lambda functions deploy correctly
2. **CloudFormation Quick Deploy**: Ensure student deployment link works
3. **Student Environment**: Validate k3s cluster setup with all fixes
4. **Evaluation System**: Test secure evaluation and token generation
5. **Submission System**: Verify final submission workflow
6. **Critical Fixes**: Confirm all previous issues are resolved

## 📋 Pre-Test Requirements

### AWS Account Requirements
- Two AWS Learner Lab accounts (instructor and student)
- LabRole permissions in both accounts
- EC2 key pair created in student account
- AWS CLI configured in instructor account

### Local Requirements
- Git repository cloned
- Bash shell access
- curl and jq installed
- AWS CLI configured

## 🔧 Phase 1: Instructor Infrastructure Setup

### Test 1.1: S3 Bucket Creation
```bash
cd instructor-tools
./setup-s3-bucket.sh
```

**Expected Results:**
- ✅ S3 bucket `k8s-eval-results` created
- ✅ Proper folder structure: `evaluations/` and `submissions/`
- ✅ Bucket accessible for Lambda functions

**Validation:**
```bash
aws s3 ls s3://k8s-eval-results/
# Should show: evaluations/ and submissions/ folders
```

### Test 1.2: Evaluation Lambda Deployment
```bash
./deploy-evaluation-lambda.sh
```

**Expected Results:**
- ✅ Lambda function `k8s-task-evaluator` created
- ✅ Function URL generated and saved to `EVALUATION_ENDPOINT.txt`
- ✅ Proper timeout (300s) and memory (512MB) settings
- ✅ Dependencies included: PyYAML, requests, urllib3

**Validation:**
```bash
aws lambda get-function --function-name k8s-task-evaluator
cat EVALUATION_ENDPOINT.txt
# Should contain Function URL
```

### Test 1.3: Submission Lambda Deployment
```bash
./deploy-submission-lambda.sh
```

**Expected Results:**
- ✅ Lambda function `k8s-submission-handler` created
- ✅ Function URL generated and saved to `SUBMISSION_ENDPOINT.txt`
- ✅ Proper IAM permissions for S3 access

**Validation:**
```bash
aws lambda get-function --function-name k8s-submission-handler
cat SUBMISSION_ENDPOINT.txt
# Should contain Function URL
```

### Test 1.4: Complete Setup Validation
```bash
./test-complete-setup.sh
```

**Expected Results:**
- ✅ All components accessible
- ✅ Lambda functions responding correctly
- ✅ Ready for CloudFormation link creation

## 🚀 Phase 2: CloudFormation Quick Deploy

### Test 2.1: Template Upload and Link Creation
```bash
cd ../cloudformation
./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "your-keypair-name"
```

**Expected Results:**
- ✅ Template uploaded to S3 with public access
- ✅ CloudFormation link generated
- ✅ Template contains correct instructor endpoints

**Validation:**
- Copy the generated CloudFormation link
- Verify template is accessible via S3 URL
- Check template contains your endpoint URLs

### Test 2.2: CloudFormation Parameter Validation
Open the CloudFormation link in AWS Console:

**Expected Results:**
- ✅ Stack name pre-populated: `k8s-student-environment`
- ✅ Neptun Code parameter available
- ✅ Task selection dropdown (task-01)
- ✅ Key pair parameter with your key selected

## 🎓 Phase 3: Student Environment Deployment

### Test 3.1: Deploy Student Environment
In student AWS account:
1. Open the CloudFormation link
2. Enter Neptun Code: `TEST123`
3. Select Task: `task-01`
4. Deploy the stack

**Expected Results:**
- ✅ Stack creation starts successfully
- ✅ EC2 instance launches (t3.medium)
- ✅ Security group created with port 6443 open
- ✅ Stack completes in 5-10 minutes

**Validation:**
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name k8s-student-environment-TEST123

# Get instance IP from stack outputs
aws cloudformation describe-stacks \
  --stack-name k8s-student-environment-TEST123 \
  --query 'Stacks[0].Outputs'
```

### Test 3.2: Critical Fix Validation
SSH to the student instance:
```bash
ssh -i your-keypair.pem ubuntu@<student-ip>
```

**Test External IP Fix:**
```bash
grep -v "127.0.0.1" ~/.kube/config
# Should show external IP, not 127.0.0.1
```

**Test Security Group Fix:**
```bash
curl -k https://<external-ip>:6443/version
# Should return Kubernetes version info
```

**Test k3s Service:**
```bash
sudo systemctl status k3s
kubectl get nodes
# Node should be Ready
```

**Test Kyverno Installation:**
```bash
kubectl get pods -n kyverno
# Should show running Kyverno pods
```

**Test Service Account:**
```bash
kubectl get serviceaccount evaluator -n kube-system
kubectl get secret evaluator-token -n kube-system
# Both should exist
```

**Test Namespace Creation:**
```bash
kubectl get namespace task-01
# Should exist
```

## 🧪 Phase 4: Evaluation System Testing

### Test 4.1: Manual Evaluation Test
From debug-tools directory on a test instance:
```bash
cd debug-tools
./manual-k3s-setup.sh
```

**Expected Results:**
- ✅ Creates `cluster-endpoint.txt` and `cluster-token.txt`
- ✅ All critical fixes applied
- ✅ Ready for evaluation testing

### Test 4.2: Request Evaluation
```bash
cd ../student-tools
./request-evaluation.sh task-01
```

**Expected Results:**
- ✅ Connects to evaluation Lambda successfully
- ✅ Returns evaluation results
- ✅ Creates `eval-token-task-01.txt`
- ✅ No kubectl errors (uses API calls)

**Critical Validations:**
- Lambda receives cluster credentials
- API calls work (not kubectl commands)
- Namespace evaluation succeeds
- Token generation works

### Test 4.3: Lambda Functionality Test
Check Lambda logs:
```bash
aws logs tail /aws/lambda/k8s-task-evaluator --follow
```

**Expected Results:**
- ✅ No "kubectl: command not found" errors
- ✅ Successful API connections
- ✅ Proper namespace evaluation
- ✅ Token generation logged

## 📝 Phase 5: Submission System Testing

### Test 5.1: Final Submission
```bash
./submit-final.sh task-01
# Enter 'yes' when prompted
```

**Expected Results:**
- ✅ Uses evaluation token from previous step
- ✅ Submission succeeds
- ✅ Confirmation message displayed
- ✅ File stored in S3

### Test 5.2: Submission Validation
```bash
aws s3 ls s3://k8s-eval-results/submissions/task-01/TEST123/ --recursive
```

**Expected Results:**
- ✅ Submission file exists
- ✅ Contains timestamp and evaluation data
- ✅ JSON format valid

## 🔄 Phase 6: Complete Workflow Test

### Test 6.1: End-to-End Student Experience
Run the complete workflow test:
```bash
cd debug-tools
./test-student-workflow.sh
```

**Expected Results:**
- ✅ All prerequisites checked
- ✅ Evaluation request succeeds
- ✅ Token creation works
- ✅ Submission completes
- ✅ No errors throughout process

### Test 6.2: Professor Demonstration Readiness
Test instructor validation:
```bash
cd ../instructor-tools
./test-complete-setup.sh
```

**Expected Results:**
- ✅ All components ready
- ✅ No missing files or endpoints
- ✅ Quick deploy link ready to share

## 🚨 Critical Issues Checklist

Verify these previously identified issues are resolved:

### ✅ Lambda kubectl Dependency
- **Issue**: Lambda functions tried to use kubectl (not available)
- **Fix**: evaluator.py uses requests library for Kubernetes API calls
- **Test**: Check Lambda logs for API calls, not kubectl commands

### ✅ External IP Configuration
- **Issue**: kubeconfig contained 127.0.0.1 instead of external IP
- **Fix**: CloudFormation template gets external IP and updates kubeconfig
- **Test**: Verify kubeconfig contains external IP, not 127.0.0.1

### ✅ Security Group Port 6443
- **Issue**: Port 6443 not accessible from internet
- **Fix**: CloudFormation automatically adds security group rule
- **Test**: Curl to https://external-ip:6443 should work

### ✅ Service Account Token Creation
- **Issue**: Service account tokens not created properly
- **Fix**: CloudFormation creates service account and token with fallback
- **Test**: Service account and secret should exist

### ✅ Namespace Naming Consistency
- **Issue**: task-task-01 vs task-01 namespace confusion
- **Fix**: Consistent task-01 namespace throughout
- **Test**: Only task-01 namespace should exist

## 📊 Success Criteria

### Minimum Viable Test
- [ ] Instructor infrastructure deploys without errors
- [ ] CloudFormation link is generated
- [ ] Student environment deploys successfully
- [ ] SSH access works
- [ ] kubectl commands work with external access
- [ ] Evaluation request succeeds
- [ ] Submission completes

### Production Ready Test
- [ ] All critical fixes validated
- [ ] No kubectl errors in Lambda logs
- [ ] External IP properly configured
- [ ] Port 6443 accessible
- [ ] Service accounts created correctly
- [ ] Complete workflow runs without intervention
- [ ] Professor demonstration ready

## 🛠️ Troubleshooting Guide

### If Test 1.x Fails (Instructor Setup)
- Check AWS CLI configuration
- Verify LabRole permissions
- Ensure correct region (us-east-1)

### If Test 2.x Fails (CloudFormation)
- Verify S3 bucket permissions
- Check template upload success
- Validate endpoint URLs in template

### If Test 3.x Fails (Student Environment)
- Check key pair exists in student account
- Verify stack creation permissions
- Review CloudFormation events for errors

### If Test 4.x Fails (Evaluation)
- Check Lambda logs in CloudWatch
- Verify cluster credentials
- Test API connectivity manually

### If Test 5.x Fails (Submission)
- Verify evaluation token exists
- Check S3 bucket permissions
- Validate submission Lambda logs

## 🎯 Next Steps After Testing

1. **If all tests pass**: Framework is ready for production use
2. **If tests fail**: Follow troubleshooting guide and re-test
3. **For professor demo**: Use debug-tools for manual demonstration
4. **For student deployment**: Share CloudFormation link from Phase 2

---

**Ready to begin testing? Start with Phase 1 and work through each phase systematically.**