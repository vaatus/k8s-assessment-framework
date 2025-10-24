# Kubernetes Assessment Framework

A cross-account Kubernetes assessment system for automated student evaluation using AWS Lambda, K3s, and CloudFormation.

## Overview

This framework enables instructors to deploy a complete Kubernetes assessment infrastructure where students can:
- Deploy their own K3s cluster in AWS Learner Lab
- Complete assigned Kubernetes tasks in isolated namespaces
- Request automated evaluation of their work via remote Lambda functions
- Submit final results for instructor grading

**Architecture**: Cross-account setup where instructor's Lambda functions remotely evaluate student K3s clusters via Kubernetes API.

## Key Features

- ✅ **Fully Automated**: One-command deployment for instructors, zero manual configuration for students
- ✅ **Cross-Account**: Instructor and students use separate AWS accounts (AWS Learner Lab compatible)
- ✅ **Remote Evaluation**: Lambda functions connect to student clusters via service account tokens
- ✅ **Multi-Task Support**: Three task types supported (Deployments, StatefulSets, Multi-Service)
- ✅ **Dynamic Evaluation**: Task-specific validation based on YAML specifications
- ✅ **HTTP Endpoint Testing**: Test-runner pods execute application-level checks inside cluster
- ✅ **Task Isolation**: Each task uses its own Kubernetes namespace
- ✅ **Secure**: API key authentication, private S3 storage for results
- ✅ **Scalable**: Support for multiple students and tasks
- ✅ **Extensible**: Easy to add new tasks with custom validation logic
- ✅ **Policy Enforcement**: Kyverno policies installed for advanced scenarios

## Quick Start

### For Instructors

1. **Prerequisites**:
   - Active AWS Learner Lab account with admin access
   - AWS CLI configured with credentials
   - Python 3.x installed

2. **Deploy Infrastructure** (one command):
   ```bash
   cd instructor-tools
   ./deploy-complete-setup.sh
   ```

3. **Share Landing Page** with students:
   ```
   https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html
   ```

4. **View Results**:
   ```bash
   ./view-results.sh
   ```

### For Students

1. Visit the landing page URL provided by instructor
2. Click "Deploy My Environment"
3. Enter your Neptun Code (e.g., TEST01)
4. Select your assigned task (task-01, task-02, or task-03)
5. Wait for CloudFormation stack creation (~5-10 minutes)
6. SSH to your EC2 instance
7. Complete the task and run:
   ```bash
   ~/student-tools/request-evaluation.sh task-01
   ~/student-tools/submit-final.sh task-01
   ```

## Repository Structure

```
k8s-assessment-framework/
├── cloudformation/
│   └── unified-student-template.yaml          # Student CloudFormation template
├── evaluation/
│   └── lambda/
│       ├── evaluator.py                       # Evaluation Lambda function
│       └── requirements.txt                   # Python dependencies (PyYAML, requests)
├── submission/
│   └── lambda/
│       └── submitter.py                       # Submission Lambda function
├── instructor-tools/
│   ├── deploy-complete-setup.sh               # Main deployment script
│   ├── view-results.sh                        # View student results
│   ├── test-complete-deployment.sh            # Test infrastructure
│   ├── check-prerequisites.sh                 # Pre-deployment checks
│   └── reupload-template.sh                   # Quick template re-upload
├── tasks/
│   └── task-01/
│       └── README.md                          # Task description
├── policies/
│   └── (Kyverno policy examples)
├── README.md                                  # This file
├── FULL_SETUP_GUIDE.md                        # Complete testing guide
└── LICENSE
```

## How It Works

### Infrastructure (Instructor Side)

1. **S3 Buckets**:
   - `k8s-assessment-templates`: Stores CloudFormation template and landing page (public read)
   - `k8s-eval-results`: Stores evaluation and submission results (private)

2. **Lambda Functions**:
   - **Evaluator**: Remotely connects to student K3s clusters, validates deployments, calculates scores
   - **Submitter**: Validates eval tokens and stores final submissions

3. **API Authentication**: Randomly generated API key shared via CloudFormation parameters

### Student Environment (Auto-Created)

Each student stack creates:
- VPC with public subnet
- EC2 instance (t3.medium) with K3s cluster
- Kyverno policy engine
- Task-specific namespace
- Service account with cluster-admin role (for remote evaluation)
- Student tools (evaluation and submission scripts)
- Task workspace with README
- Auto-shutdown after 4 hours

### Evaluation Flow

1. Student completes task (creates Kubernetes resources)
2. Student runs `request-evaluation.sh task-01`
3. Script sends cluster endpoint and service account token to evaluation Lambda
4. Lambda remotely connects to student's K3s API
5. Lambda validates deployment, replicas, images, labels, pods, resources
6. Lambda calculates score and returns eval_token
7. Lambda stores results in S3: `evaluations/{student_id}/{task_id}/{eval_token}.json`

### Submission Flow

1. Student reviews evaluation results
2. Student runs `submit-final.sh task-01`
3. Script runs evaluation again to get latest eval_token
4. Script sends eval_token to submission Lambda
5. Lambda validates eval_token exists in S3
6. Lambda creates final submission with timestamp
7. Lambda stores in S3: `submissions/{student_id}/{task_id}/{timestamp}.json`

## S3 Storage Structure

```
k8s-eval-results/
├── evaluations/
│   └── {student_id}/          # e.g., TEST01
│       └── {task_id}/         # e.g., task-01
│           └── {eval_token}.json
└── submissions/
    └── {student_id}/
        └── {task_id}/
            └── {timestamp}.json
```

## Supported Tasks

### Task 01: NGINX Deployment (Simple)
**Type**: Deployment validation
**Complexity**: Beginner
**Evaluation**: Kubernetes resource checks only

| Criterion | Points |
|-----------|--------|
| Deployment exists | 20 |
| Replicas correct (2) | 15 |
| Image correct (nginx) | 15 |
| Resources set | 20 |
| Labels correct | 10 |
| Pod count correct | 10 |
| Pods running | 10 |
| **Total** | **100** |

### Task 02: StatefulSet Key-Value Store (Advanced)
**Type**: StatefulSet with persistent storage
**Complexity**: Intermediate
**Evaluation**: Resource checks + HTTP endpoint testing

| Criterion | Points |
|-----------|--------|
| StatefulSet exists | 15 |
| Replica count (4) | 10 |
| PVCs created | 15 |
| Headless service | 10 |
| Pods running | 10 |
| Store data (POST) | 10 |
| Retrieve data (GET) | 10 |
| Data persistence | 20 |
| **Total** | **100** |

### Task 03: Health Probes & Graceful Shutdown (Complex)
**Type**: Multi-service application
**Complexity**: Advanced
**Evaluation**: Resource checks + HTTP testing + probe configuration

| Criterion | Points |
|-----------|--------|
| Backend deployment | 5 |
| Frontend deployment | 5 |
| Services exist | 10 |
| Backend endpoints | 20 |
| Frontend endpoints | 40 |
| Probes configured | 20 |
| **Total** | **100** |

## Key Technical Details

### API Key Consistency

The deployment script checks if `API_KEY.txt` exists and reuses it. This ensures:
- Lambda functions use the same key across deployments
- Student stacks deployed before redeployment continue to work
- No manual key synchronization needed

### Public IP for Cluster Access

Student K3s clusters use public IP instead of localhost:
```bash
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
KUBE_API="https://$PUBLIC_IP:6443"
```

### Task-Specific Namespaces

Each task uses its own namespace for isolation:
- task-01 → namespace: task-01
- task-02 → namespace: task-02
- task-03 → namespace: task-03

### Label Validation

The evaluator checks **pod template labels** (not deployment metadata labels):
```python
pod_template_labels = deployment.get('spec', {}).get('template', {}).get('metadata', {}).get('labels', {})
results['labels_correct'] = (pod_template_labels.get('app') == 'nginx')
```

## AWS Learner Lab Constraints

- **Session Duration**: 4 hours (all resources deleted after)
- **EC2 Instance**: t3.medium (2 vCPU, 4 GB RAM)
- **Lambda**: 512 MB memory, 300s timeout
- **Budget**: $50 total per learner

Students must complete work within session limits.

## Redeployment After Session Expires

When AWS Learner Lab session expires:

1. Start new session
2. Configure AWS CLI with new credentials
3. Run `./deploy-complete-setup.sh` (reuses API key if available)
4. Share new landing page URL with students
5. Students delete old stack and deploy new one

## Security Considerations

- **API Key**: 32-character random hex, validated on every request
- **S3 Access**: Templates bucket public (required), results bucket private
- **Lambda URLs**: Public endpoints with application-level auth (IAM not available in Learner Lab)
- **K3s Certificates**: Self-signed, SSL verification disabled (insecure-skip-tls-verify)
- **Service Account**: cluster-admin role (required for full evaluation)

## Extending the Framework

### Adding New Tasks

1. Edit `cloudformation/unified-student-template.yaml`
2. Add to `TaskConfiguration` mapping (lines 97-109)
3. Add to `TaskSelection` allowed values
4. Add task README in UserData section (lines 328-418)
5. Create task directory: `tasks/task-04/README.md`
6. Update evaluator.py if task requires different validation logic
7. Redeploy: `./reupload-template.sh`

### Modifying Evaluation Logic

1. Edit `evaluation/lambda/evaluator.py`
2. Update `evaluate_task()` function for your criteria
3. Update `calculate_score()` function for point allocation
4. Redeploy: `./deploy-complete-setup.sh`

### Custom Policies

Place Kyverno policies in `policies/` directory and add to CloudFormation UserData for automatic installation.

## Troubleshooting

**Lambda 502 Error**: Run `./deploy-complete-setup.sh` to redeploy with dependencies

**API Key Mismatch**: Check `API_KEY.txt` matches Lambda environment variable

**Cluster Connection Failed**: Verify security group allows inbound on port 6443

**Namespace Not Found**: Ensure student deployed resources to task-specific namespace

**Stack Creation Failed**: Check CloudFormation events and UserData logs: `/var/log/user-data.log`

## Documentation

### For Instructors
- `FULL_SETUP_GUIDE.md` - Complete deployment and testing guide (basic system)
- `MULTI_TASK_DEPLOYMENT_GUIDE.md` - Advanced multi-task system deployment
- `tasks/task-spec-format.md` - Task specification format reference

### For Students
- `tasks/task-01/README.md` - NGINX deployment task
- `tasks/task-02/README.md` - StatefulSet task
- `tasks/task-03/README.md` - Health probes task

### For Developers
- `evaluation/test-runner/README.md` - Test-runner pod documentation
- `evaluation/lambda/evaluator.py` - Simple evaluator (task-01 only)
- `evaluation/lambda/evaluator_dynamic.py` - Dynamic evaluator (all tasks)

## System Versions

### Simple System (v1.0)
- Single evaluator: `evaluator.py`
- Supports: task-01 only
- Evaluation: Kubernetes resource validation
- Suitable for: Basic deployment tasks

### Advanced System (v2.0)
- Dynamic evaluator: `evaluator_dynamic.py`
- Supports: task-01, task-02, task-03, and custom tasks
- Evaluation: Resource validation + HTTP endpoint testing
- Features: Test-runner pods, task specifications, flexible scoring
- Suitable for: Complex, application-level tasks

## Deployment Modes

Choose during `deploy-complete-setup.sh`:
1. **Simple mode**: Uses `evaluator.py` (faster, task-01 only)
2. **Advanced mode**: Uses `evaluator_dynamic.py` (full features, all tasks)

## License

See [LICENSE](LICENSE) file for details.

## Contributing

This is a thesis project. For issues or feature requests, please open a GitHub issue.

---

**Status**: Production Ready ✅

- **Simple System**: Tested and verified (task-01)
- **Advanced System**: Implemented and ready for testing (task-01, task-02, task-03)

Last updated: 2025-10-23
