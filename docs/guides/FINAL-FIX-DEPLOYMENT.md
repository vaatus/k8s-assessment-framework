# Final Fix - Test-Runner JSON Parsing Issue

## Root Cause Found

The test-runner was outputting **pretty-printed JSON** (with `indent=2`), but the Lambda parser expected single-line JSON starting with `{`.

## Fixes Applied

### 1. Test-Runner (evaluation/test-runner/test_runner.py)
- **Before:** `print(json.dumps(output, indent=2))` - Pretty-printed, multi-line
- **After:** `print(json.dumps(output))` - Single-line JSON

### 2. Lambda Parser (evaluation/lambda/evaluator_dynamic.py)
- Added robust parsing for both single-line AND multi-line JSON
- Added better error handling and debugging
- Added `wait_for_pod_completion()` to ensure pod finishes before reading logs

## Deployment Steps

### Run the deploy script:

```bash
cd /home/taha/k8s-assessment-framework/instructor-tools

./deploy-complete-setup.sh
```

**Answer prompts:**
- Continue? → `yes`
- Build and upload Docker images? → `yes` (MUST rebuild test-runner with fix!)

This will:
1. ✅ Rebuild test-runner image with single-line JSON output
2. ✅ Upload test-runner to S3
3. ✅ Import test-runner to K3s on EC2
4. ✅ Rebuild Lambda with improved parser
5. ✅ Deploy Lambda

### Then test on EC2:

```bash
ssh ubuntu@<EC2-IP>

# Delete old test-runner image
sudo k3s ctr images rm docker.io/library/test-runner:latest

# Re-import from S3 (CloudFormation will do this on next instance)
# Or manually:
aws s3 cp s3://k8s-assessment-templates/docker-images/test-runner.tar /tmp/
sudo k3s ctr images import /tmp/test-runner.tar

# Test evaluation
~/student-tools/request-evaluation.sh task-03
```

**Expected Result: 100/100!**

## What Changed

| Component | Before | After |
|-----------|--------|-------|
| test_runner.py | Pretty JSON (multi-line) | Single-line JSON |
| evaluator Lambda | Only parsed single-line | Parses both formats |
| Pod wait | 5 second sleep | Wait for completion |
| Error handling | Basic | Verbose with traceback |

## Verification

Check Lambda logs after evaluation:

```bash
aws logs tail /aws/lambda/k8s-evaluation-function --since 2m | grep "Found results"
```

Should see:
```
Found results in single-line JSON: ['backend_get_config', 'backend_ping', ...]
Parsed 5 test results
  backend_get_config: True
  backend_ping: True
  ...
```

## If Still Failing

Check if test-runner image was actually rebuilt:

```bash
# On EC2
sudo k3s ctr images ls | grep test-runner

# Should show recent timestamp
```

If timestamp is old, manually rebuild:

```bash
cd /home/taha/k8s-assessment-framework/instructor-tools
./build-and-upload-images.sh

# Then on EC2, delete and re-import
ssh ubuntu@<EC2-IP>
sudo k3s ctr images rm docker.io/library/test-runner:latest
aws s3 cp s3://k8s-assessment-templates/docker-images/test-runner.tar /tmp/
sudo k3s ctr images import /tmp/test-runner.tar
```

---

**This should finally achieve 100/100 on task-03!** 🎯
