# Task Specification Quick Guide

## Overview

The evaluation system is **fully dynamic** - it reads task specifications from YAML files to determine:
- ✅ What Kubernetes resources to validate
- ✅ What HTTP endpoints to test
- ✅ What probes to check
- ✅ How to calculate scores

## Quick Start

### 1. See Working Examples

```bash
# Simple deployment validation only
cat tasks/task-01/task-spec.yaml

# StatefulSet with HTTP endpoint testing
cat tasks/task-02/task-spec.yaml

# Multi-service with health probes
cat tasks/task-03/task-spec.yaml
```

### 2. Use the Template

Copy and customize:
```bash
cp tasks/task-spec.example.yaml tasks/task-04/task-spec.yaml
```

The example file is **heavily commented** (like Bitnami Helm values.yaml) to show every available option.

### 3. Upload to S3

```bash
aws s3 cp tasks/task-04/task-spec.yaml \
  s3://k8s-eval-results/task-specs/task-04/task-spec.yaml
```

### 4. Deploy Student Environment

Students select task-04 during CloudFormation deployment. The evaluator automatically loads the spec from S3.

---

## Core Concepts

### Resource Validation

Define what K8s resources must exist:

```yaml
required_resources:
  deployments:
    - name: "my-app"
      replicas: 2
      selector_labels: {app: my-app}

  statefulsets:
    - name: "my-db"
      replicas: 3
      volumeClaimTemplates: [{name: data}]

  services:
    - name: "my-service"
      type: "ClusterIP"
```

Evaluator checks:
- ✅ Resource exists
- ✅ Replica count matches
- ✅ Labels match
- ✅ Pods are running
- ✅ PVCs created (for StatefulSets)

### Application Checks

Test HTTP endpoints using test-runner pod:

```yaml
application_checks:
  - check_id: "health_check"
    check_type: "http_get"
    service: "my-service"
    port: 8080
    path: "/health"
    expected_status: 200
```

Evaluator:
1. Deploys test-runner pod in student namespace
2. Test-runner makes HTTP requests from inside cluster
3. Returns pass/fail for each check

### Scoring

Map results to points:

```yaml
scoring:
  max_score: 100
  criteria:
    - id: "deployment_exists"   # Fuzzy matches "deployment_my-app_exists"
      points: 20
    - id: "health_check"         # Exact match from application_checks
      points: 10
```

**Fuzzy Matching Rules:**
- `deployment_exists` → `deployment_<name>_exists`
- `replicas_correct` → `deployment_<name>_replicas_correct` OR `statefulset_<name>_replicas_correct`
- Exact matches take priority

---

## Adding a New Task

### Step 1: Create Task Spec

```bash
mkdir -p tasks/task-04
cat > tasks/task-04/task-spec.yaml <<EOF
task_id: "task-04"
task_name: "My Custom Task"
namespace: "task-04"

required_resources:
  deployments:
    - name: "web-app"
      replicas: 2
      selector_labels: {app: web}

application_checks:
  - check_id: "homepage"
    check_type: "http_get"
    service: "web-service"
    port: 80
    path: "/"
    expected_status: 200

scoring:
  max_score: 100
  criteria:
    - {id: "deployment_exists", points: 50}
    - {id: "pods_running", points: 30}
    - {id: "homepage", points: 20}
EOF
```

### Step 2: Upload to S3

```bash
./instructor-tools/upload-task-specs.sh
```

### Step 3: Update CloudFormation (Optional)

Add task-04 to allowed values in `cloudformation/unified-student-template.yaml`:

```yaml
Parameters:
  TaskSelection:
    Type: String
    AllowedValues:
      - task-01
      - task-02
      - task-03
      - task-04  # Add this
```

### Step 4: Test

Deploy student stack with task-04, create resources, run evaluation.

---

## Advanced Features

### Probe Validation

Check if liveness/startup probes are configured:

```yaml
probe_checks:
  - check_id: "liveness_configured"
    deployment: "frontend"
    probe_type: "liveness"
    path: "/health"
    period_seconds: 5
    failure_threshold: 3
```

### Custom Checks (Placeholder)

Document complex validation steps:

```yaml
custom_checks:
  - check_id: "data_persistence"
    points: 20
    validation_steps:
      - store_data_in_pod
      - delete_pod
      - verify_data_exists_after_restart
```

> **Note**: Custom checks with validation_steps are documentation-only. You must implement the logic in evaluator_dynamic.py.

---

## File Locations

```
tasks/
├── task-spec.example.yaml        # Heavily commented template
├── TASK_SPEC_GUIDE.md            # This file
├── task-01/task-spec.yaml        # Simple deployment example
├── task-02/task-spec.yaml        # StatefulSet with HTTP checks
└── task-03/task-spec.yaml        # Multi-service with probes
```

---

## Troubleshooting

### Criterion not scoring

Check fuzzy matching:
```python
# In evaluator_dynamic.py, enable debug:
print(f"DEBUG: All result keys: {list(results.keys())}")
```

### Application check failing

Check test-runner logs:
```bash
kubectl logs -l app=test-runner -n task-02
```

### Task spec not loading

Verify S3 upload:
```bash
aws s3 ls s3://k8s-eval-results/task-specs/task-02/
```

---

## See Also

- `evaluation/lambda/evaluator_dynamic.py` - Evaluation logic
- `evaluation/test-runner/test_runner.py` - HTTP check implementation
- `DYNAMIC_SETUP_TESTING_GUIDE.md` - Full deployment guide

---

**Status**: Production Ready ✅

The dynamic evaluation system is tested and working:
- ✅ task-01: Deployment validation
- ✅ task-02: StatefulSet + HTTP checks (100/100 score verified)
- ✅ task-03: Multi-service + probes (ready for testing)
