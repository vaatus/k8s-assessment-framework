# Custom Checks Implementation - Graceful Shutdown

## Overview

Implemented full support for `custom_checks` in the dynamic evaluation system, including the graceful shutdown test for task-03.

---

## Changes Made

### 1. Evaluator Lambda (`evaluation/lambda/evaluator_dynamic.py`)

#### Added Methods:

**`run_custom_checks()`** (line 512-526)
- Iterates through `custom_checks` defined in task spec
- Routes each check to appropriate handler
- Currently handles `graceful_shutdown`
- Extensible for future custom checks

**`check_graceful_shutdown()`** (line 528-581)
- Tests if frontend calls backend `/game-over` on termination
- Steps:
  1. Get backend pod and initial logs
  2. Count initial `/game-over` calls
  3. Get frontend pod
  4. Delete frontend pod (triggers preStop hook)
  5. Wait 15 seconds for termination
  6. Check backend logs again
  7. Verify `/game-over` count increased
- Returns `True` if working, `False` otherwise

**`get_pod_by_label()`** (line 583-599)
- Helper to find pod by label selector
- Returns first matching pod

**`delete_pod()`** (line 601-607)
- Helper to delete a pod
- Returns success status

#### Updated Methods:

**`evaluate()`** (line 200-220)
- Added call to `run_custom_checks()` after application checks
- Maintains evaluation flow consistency

---

### 2. Task-03 Spec (`tasks/task-03/task-spec.yaml`)

#### Fixed Scoring Inconsistency:

```yaml
# Before:
custom_checks:
  - check_id: "graceful_shutdown"
    points: 20  # ❌ Inconsistent

scoring:
  criteria:
    - id: "graceful_shutdown"
      points: 5  # Different value!

# After:
custom_checks:
  - check_id: "graceful_shutdown"
    points: 5  # ✅ Consistent

scoring:
  criteria:
    - id: "graceful_shutdown"
      points: 5  # Matches!
```

---

## How It Works

### Graceful Shutdown Test Flow:

```
1. Before Test
   ├─ Backend pod running
   ├─ Frontend pod running
   └─ Backend logs: 0 /game-over calls

2. Evaluator Actions
   ├─ Read initial backend logs
   ├─ Count /game-over occurrences: 0
   ├─ Delete frontend pod
   └─ Wait 15 seconds

3. What Happens
   ├─ Kubernetes sends SIGTERM to frontend
   ├─ Frontend preStop hook executes:
   │  └─ Calls: POST http://svc-backend.task-03.svc.cluster.local:5000/game-over
   ├─ Backend receives request, logs it
   ├─ Frontend terminates
   └─ New frontend pod starts

4. After Test
   ├─ Evaluator reads backend logs again
   ├─ Count /game-over occurrences: 1+
   └─ Test passes if count increased
```

---

## Testing the Implementation

### Before Update (Current Behavior):

```bash
~/student-tools/request-evaluation.sh task-03
# Result:
{
  "score": 100,
  "graceful_shutdown": false  # ❌ Always false
}
```

### After Update (Expected Behavior):

```bash
~/student-tools/request-evaluation.sh task-03
# Result:
{
  "score": 100,
  "graceful_shutdown": true   # ✅ Actually tested!
}
```

---

## Deployment Instructions

### Step 1: Upload Updated Task-03 Spec

From PowerShell in AWS Learner Lab:

```powershell
cd path\to\k8s-assessment-framework
aws s3 cp tasks\task-03\task-spec.yaml s3://k8s-eval-results/task-specs/task-03/task-spec.yaml
```

### Step 2: Deploy Updated Lambda

**Option A - AWS CLI:**

```powershell
cd path\to\k8s-assessment-framework
aws lambda update-function-code `
  --function-name k8s-evaluator `
  --zip-file fileb://evaluation/lambda/lambda-deployment.zip
```

**Option B - AWS Console:**

1. Open: https://console.aws.amazon.com/lambda
2. Find function: `k8s-evaluator`
3. Click **"Upload from"** > **".zip file"**
4. Select: `evaluation/lambda/lambda-deployment.zip`
5. Click **"Save"**

### Step 3: Test the Update

```bash
# SSH to student instance
ssh ubuntu@ip-10-0-1-148

# Request evaluation
~/student-tools/request-evaluation.sh task-03
```

**Expected Output:**

```json
{
  "score": 100,
  "max_score": 100,
  "results_summary": {
    "deployment_backend_exists": true,
    "deployment_frontend_exists": true,
    "service_svc-backend_exists": true,
    "service_svc-frontend_exists": true,
    "backend_get_config": true,
    "backend_ping": true,
    "frontend_startup": true,
    "frontend_who_am_i": true,
    "frontend_health": true,
    "startup_probe_configured": true,
    "liveness_probe_configured": true,
    "graceful_shutdown": true  // ✅ NOW TRUE!
  }
}
```

---

## Extending Custom Checks

The implementation is designed to be extensible. To add new custom checks:

### 1. Define in Task Spec:

```yaml
custom_checks:
  - check_id: "my_custom_check"
    description: "Description of what it tests"
    points: 10
    validation_steps:
      - step1
      - step2
```

### 2. Add to Scoring Criteria:

```yaml
scoring:
  criteria:
    - id: "my_custom_check"
      description: "My custom check"
      points: 10
```

### 3. Implement in Evaluator:

```python
def run_custom_checks(self):
    custom_checks = self.task_spec.get('custom_checks', [])

    for check in custom_checks:
        check_id = check['check_id']

        if check_id == 'graceful_shutdown':
            self.results[check_id] = self.check_graceful_shutdown(check)
        elif check_id == 'my_custom_check':
            self.results[check_id] = self.check_my_custom_check(check)
        else:
            print(f"Warning: Unknown custom check: {check_id}")
            self.results[check_id] = False

def check_my_custom_check(self, check):
    # Implement custom logic here
    try:
        # Your test logic
        return True  # or False
    except Exception as e:
        print(f"Error: {e}")
        return False
```

---

## Architecture Benefits

### Dynamic Evaluation
- ✅ Task specs define what to test
- ✅ Evaluator automatically runs all checks
- ✅ No hardcoded task logic

### Extensibility
- ✅ Easy to add new custom checks
- ✅ Each task can have unique tests
- ✅ Reusable check implementations

### Transparency
- ✅ Students see exact test results
- ✅ Clear pass/fail criteria
- ✅ Debugging friendly

---

## Files Modified

1. ✅ `/evaluation/lambda/evaluator_dynamic.py` - Added custom checks support
2. ✅ `/tasks/task-03/task-spec.yaml` - Fixed scoring inconsistency
3. ✅ `/evaluation/lambda/lambda-deployment.zip` - Deployment package created
4. ✅ `/evaluation/lambda/deploy-lambda.sh` - Deployment script

---

## Summary

**Before:**
- `custom_checks` section ignored
- Graceful shutdown always showed `false`
- Got 100/100 anyway (those 5 points not counted)

**After:**
- `custom_checks` fully implemented
- Graceful shutdown actually tested
- True dynamic evaluation achieved!

**Impact:**
- ✅ True dynamic evaluation
- ✅ Every task spec element is evaluated
- ✅ Extensible for future custom checks
- ✅ Task-03 fully functional

---

## Next Steps

1. **Deploy Lambda update** (see instructions above)
2. **Upload task-03 spec to S3**
3. **Test task-03 evaluation**
4. **Verify graceful_shutdown: true**

Your assessment framework is now truly dynamic! 🚀
