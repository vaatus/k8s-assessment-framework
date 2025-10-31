# Multi-Task System Deployment Guide

Complete guide for deploying and using the advanced multi-task evaluation system.

## Overview

The framework now supports multiple task types with:
- **Dynamic evaluation** based on task specifications
- **HTTP endpoint testing** using test-runner pods
- **Multiple resource types**: Deployments, StatefulSets, Services, PVCs
- **Application-level checks**: Health probes, graceful shutdown, data persistence
- **Flexible scoring** configured per task

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Instructor Side (AWS)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐ │
│  │  S3 Buckets  │      │   Lambda     │      │    S3     │ │
│  │              │      │              │      │  Task     │ │
│  │ - Results    │◄─────┤  Evaluator   │◄─────┤  Specs    │ │
│  │ - Templates  │      │  (Dynamic)   │      │           │ │
│  └──────────────┘      └──────┬───────┘      └───────────┘ │
│                                │                             │
└────────────────────────────────┼─────────────────────────────┘
                                 │
                                 │ Kubernetes API
                                 │
┌────────────────────────────────┼─────────────────────────────┐
│                    Student Side (AWS)                         │
├────────────────────────────────┼─────────────────────────────┤
│                                ▼                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            K3s Cluster (task-XX namespace)            │   │
│  │                                                        │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐ │   │
│  │  │ Deployments │  │StatefulSets │  │ Services/PVCs│ │   │
│  │  └─────────────┘  └─────────────┘  └──────────────┘ │   │
│  │                                                        │   │
│  │  ┌──────────────────────────────────────────────┐    │   │
│  │  │   Test-Runner Pod (temporary)                │    │   │
│  │  │   - Runs HTTP endpoint tests                 │    │   │
│  │  │   - Reports results to Lambda                │    │   │
│  │  └──────────────────────────────────────────────┘    │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## System Components

### 1. Dynamic Evaluator (`evaluator_dynamic.py`)

**Features**:
- Loads task specifications from S3 or embedded specs
- Validates Kubernetes resources (deployments, statefulsets, services, PVCs)
- Deploys test-runner pods for HTTP endpoint testing
- Checks probe configuration
- Calculates scores based on task criteria

**Environment Variables**:
- `S3_BUCKET`: Results bucket name
- `API_KEY`: Authentication key
- `TEST_RUNNER_IMAGE`: Docker image for test-runner pod (optional)

### 2. Test-Runner Pod

**Purpose**: Execute application-level tests inside the student cluster

**Features**:
- HTTP GET/POST endpoint testing
- Response validation (status codes, body content, JSON fields)
- Service-to-service communication testing
- Runs in student's namespace

**Image**: `test-runner:latest` (must be built and published)

### 3. Task Specifications

**Format**: YAML files defining task requirements

**Location**: `s3://k8s-eval-results/task-specs/{task-id}/task-spec.yaml`

**Structure**:
```yaml
task_id: "task-XX"
task_name: "Task Name"
task_type: "deployment|statefulset|multi-service"
namespace: "task-XX"

required_resources:
  deployments: [...]
  statefulsets: [...]
  services: [...]

application_checks:
  - check_id: "..."
    check_type: "http_get|http_post"
    service: "..."
    path: "..."
    expected_status: 200

scoring:
  max_score: 100
  criteria:
    - id: "criterion_id"
      points: 10
```

## Deployment Steps

### Phase 1: Build Test-Runner Image

**Prerequisites**:
- Docker installed
- Access to container registry (Docker Hub, ECR, etc.)

```bash
cd evaluation/test-runner

# Build image
docker build -t test-runner:latest .

# Tag for your registry
docker tag test-runner:latest <your-registry>/test-runner:latest

# Push to registry
docker push <your-registry>/test-runner:latest
```

**Note**: Update `TEST_RUNNER_IMAGE` environment variable in Lambda with your image URL.

### Phase 2: Deploy Infrastructure

```bash
cd instructor-tools

# Check prerequisites
./check-prerequisites.sh

# Deploy complete infrastructure
./deploy-complete-setup.sh
```

**Interactive Prompts**:
1. Confirm deployment: Type `yes`
2. Choose evaluator version:
   - Option 1: Simple evaluator (task-01 only)
   - Option 2: Dynamic evaluator (all tasks) ← **Select this**

**What Gets Deployed**:
- S3 buckets (results, templates)
- Evaluation Lambda (with dynamic evaluator)
- Submission Lambda
- CloudFormation template
- Student landing page

**Output Files**:
- `EVALUATION_ENDPOINT.txt`
- `SUBMISSION_ENDPOINT.txt`
- `API_KEY.txt`

### Phase 3: Upload Task Specifications

```bash
cd instructor-tools

# Upload all task specs to S3
./upload-task-specs.sh
```

**What Gets Uploaded**:
- `task-01/task-spec.yaml` → S3
- `task-02/task-spec.yaml` → S3
- `task-03/task-spec.yaml` → S3

### Phase 4: Update Lambda Environment

Set the test-runner image URL in Lambda:

```bash
API_KEY=$(cat API_KEY.txt)
TEST_RUNNER_IMAGE="<your-registry>/test-runner:latest"

aws lambda update-function-configuration \
  --function-name k8s-evaluation-function \
  --environment "Variables={S3_BUCKET=k8s-eval-results,API_KEY=${API_KEY},TEST_RUNNER_IMAGE=${TEST_RUNNER_IMAGE}}" \
  --region us-east-1
```

### Phase 5: Test Infrastructure

```bash
./test-complete-deployment.sh
```

Expected: All checks pass ✅

## Supported Tasks

### Task 01: NGINX Deployment (Simple)
- Type: Deployment
- Resource validation only
- No HTTP testing required
- Score: 100 points

### Task 02: StatefulSet Key-Value Store (Advanced)
- Type: StatefulSet
- Resource validation + HTTP endpoint testing
- Requires: PVCs, headless service, data persistence
- Score: 100 points

### Task 03: Health Probes & Graceful Shutdown (Complex)
- Type: Multi-service (frontend + backend)
- Resource validation + HTTP testing + probe configuration
- Requires: Multiple deployments, services, startup/liveness probes
- Score: 100 points

## Adding New Tasks

### Step 1: Create Task Directory

```bash
mkdir -p tasks/task-04
```

### Step 2: Create Task Specification

Create `tasks/task-04/task-spec.yaml`:

```yaml
task_id: "task-04"
task_name: "Your Task Name"
task_type: "deployment"
namespace: "task-04"

required_resources:
  deployments:
    - name: "your-app"
      replicas: 1
      selector_labels:
        app: "your-app"

scoring:
  max_score: 100
  criteria:
    - id: "deployment_exists"
      points: 50
    - id: "pods_running"
      points: 50
```

### Step 3: Create Task README

Create `tasks/task-04/README.md` with student instructions.

### Step 4: Upload Task Spec

```bash
cd instructor-tools
./upload-task-specs.sh
```

### Step 5: Update CloudFormation

Edit `cloudformation/unified-student-template.yaml`:

1. Add task-04 to `TaskConfiguration` mapping
2. Add `task-04` to `TaskSelection` AllowedValues
3. Add task-04 README content to UserData

4. Re-upload template:
```bash
./reupload-template.sh
```

## Testing New Tasks

### Test task-02 (StatefulSet)

1. **Deploy student stack** with task-02 selected
2. **SSH to student EC2**
3. **Verify environment**:
   ```bash
   kubectl get namespace task-02
   cat ~/k8s-workspace/tasks/task-02/README.md
   ```

4. **Deploy solution** (follow README instructions)
5. **Request evaluation**:
   ```bash
   ~/student-tools/request-evaluation.sh task-02
   ```

6. **Check results**:
   - Should show score out of 100
   - Resource checks should pass
   - HTTP checks may fail if no application deployed

7. **Submit**:
   ```bash
   ~/student-tools/submit-final.sh task-02
   ```

8. **Verify from instructor side**:
   ```bash
   cd instructor-tools
   ./view-results.sh
   ```

## Evaluation Flow

1. **Student requests evaluation** via `request-evaluation.sh`
2. **Lambda receives request** with student_id, task_id, cluster credentials
3. **Lambda loads task spec** from S3
4. **Lambda validates resources**:
   - Deployments/StatefulSets exist with correct config
   - Services configured correctly
   - PVCs created (for StatefulSets)
   - Pods running
   - Probes configured
5. **Lambda deploys test-runner pod** (if application checks defined)
6. **Test-runner executes HTTP checks** inside cluster
7. **Test-runner reports results** via logs
8. **Lambda collects results** and calculates score
9. **Lambda stores evaluation** in S3
10. **Lambda returns results** to student

## Troubleshooting

### Test-Runner Pod Fails to Deploy

**Check**: Image is accessible from student cluster

```bash
# On student EC2
kubectl run test --rm -it --image=<your-registry>/test-runner:latest --restart=Never -- /bin/sh
```

**Solution**: Use public registry or import image to K3s

### HTTP Checks Always Fail

**Possible causes**:
1. Service not accessible (check service exists)
2. Application not responding (check pod logs)
3. Incorrect endpoint path

**Debug**:
```bash
# Check test-runner pod logs
kubectl logs -l job-name=test-runner -n task-XX

# Test service manually
kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-XX -- \
  curl http://service-name:port/path
```

### Lambda Timeout

**Cause**: Test-runner pod takes too long

**Solution**: Increase Lambda timeout (currently 300s)

```bash
aws lambda update-function-configuration \
  --function-name k8s-evaluation-function \
  --timeout 600 \
  --region us-east-1
```

### Task Spec Not Found

**Symptoms**: "Task specification not found for task: task-XX"

**Fix**: Upload task specs

```bash
cd instructor-tools
./upload-task-specs.sh
```

## Configuration Reference

### Lambda Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `S3_BUCKET` | Results bucket | `k8s-eval-results` |
| `API_KEY` | Authentication key | `abc123...` |
| `TEST_RUNNER_IMAGE` | Test-runner image | `your-registry/test-runner:latest` |

### Task Specification Fields

| Field | Type | Description |
|-------|------|-------------|
| `task_id` | string | Unique task identifier |
| `task_name` | string | Human-readable name |
| `task_type` | string | deployment, statefulset, multi-service |
| `namespace` | string | Kubernetes namespace |
| `required_resources` | object | Resource specifications |
| `application_checks` | array | HTTP endpoint tests |
| `probe_checks` | array | Probe configuration checks |
| `scoring` | object | Scoring criteria |

## Performance Considerations

### Lambda Execution Time

- Resource validation: ~5-10 seconds
- HTTP checks: +10-30 seconds (depends on number of checks)
- Total: ~15-40 seconds per evaluation

### Cost Optimization

- Test-runner pods are automatically deleted after use
- Use small test-runner image (currently ~50MB)
- Lambda memory: 512MB (sufficient for most tasks)
- Lambda timeout: 300s (5 minutes)

## Security Considerations

### Test-Runner Permissions

Test-runner pod runs in student namespace with no special permissions. It cannot:
- Access other namespaces
- Modify cluster configuration
- Access secrets (unless explicitly mounted)

### Lambda Permissions

Lambda needs:
- S3 read/write to results bucket
- S3 read from task-specs prefix
- No Kubernetes API permissions (uses student's token)

## Next Steps

1. **Build and publish test-runner image**
2. **Deploy infrastructure with dynamic evaluator**
3. **Upload task specifications**
4. **Test with task-01** (no HTTP checks, baseline)
5. **Test with task-02** (StatefulSet + HTTP checks)
6. **Test with task-03** (Complex multi-service)
7. **Create additional tasks as needed**
8. **Monitor Lambda logs** for issues

## Resources

- Test-runner code: `evaluation/test-runner/`
- Dynamic evaluator: `evaluation/lambda/evaluator_dynamic.py`
- Task specifications: `tasks/task-*/task-spec.yaml`
- Deployment scripts: `instructor-tools/`

---

**System Status**: Ready for Advanced Multi-Task Evaluation ✅

For questions or issues, check CloudWatch logs:
```bash
aws logs tail /aws/lambda/k8s-evaluation-function --follow
```
