# Kubernetes Assessment Framework - Complete Workflow
## Thesis Project: Remote-Controlled Assessment Framework

### Overview

This framework provides remote evaluation capabilities for Kubernetes-based exercises in Cloud Native Technologies courses. Students deploy solutions in their sandboxed AWS environments, and evaluations are performed remotely from a separate instructor-controlled AWS account.

---

## Architecture Components

### Instructor AWS Account (Learner Lab - Instructor)
- **S3 Bucket** (`k8s-eval-results`): Stores evaluation results and submissions
- **Evaluation Lambda** (`k8s-task-evaluator`): Remotely evaluates student clusters
- **Submission Lambda** (`k8s-submission-handler`): Processes final submissions
- **CloudFormation Template Storage**: Hosts student deployment templates
- **API Key Management**: Shared authentication secret

### Student AWS Account (Learner Lab - Student)
- **EC2 Instance** (t3.medium, Ubuntu 22.04): Hosts K3s cluster
- **K3s Cluster**: Lightweight Kubernetes distribution
- **Kyverno**: Policy engine for task validation
- **Task Namespace**: Isolated workspace per task
- **Student Tools**: Scripts for evaluation requests and submissions

---

## Complete Workflow

### Phase 1: Instructor Setup (One-time per Semester)

#### 1.1 Deploy Instructor Infrastructure

```bash
# Login to Instructor AWS Learner Lab CloudShell
cd ~/k8s-assessment-framework/instructor-tools

# Create S3 bucket for results storage
./setup-s3-bucket.sh

# Deploy evaluation Lambda function
# - Generates random API key (64-char hex)
# - Packages Python code with dependencies
# - Creates Lambda with Function URL (auth: NONE)
# - Sets API_KEY environment variable
./deploy-evaluation-lambda.sh

# Deploy submission Lambda function
# - Uses same API key as evaluation Lambda
# - Validates evaluation tokens before accepting submissions
./deploy-submission-lambda.sh

# Verify complete setup
./test-complete-setup.sh
```

**Expected Output:**
```
✅ S3 bucket accessible
✅ Evaluation Lambda exists
✅ Evaluation URL: https://xxxxx.lambda-url.us-east-1.on.aws/
✅ Submission Lambda exists
✅ Submission URL: https://yyyyy.lambda-url.us-east-1.on.aws/
✅ Evaluation Lambda responding correctly (with API key authentication)

🎯 Ready for quick deploy link creation!
```

#### 1.2 Create Student Deployment Link

```bash
cd ../cloudformation

# Generate CloudFormation quick-deploy link
./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/API_KEY.txt)" \
  "vockey"
```

**Outputs:**
- CloudFormation Quick Deploy URL
- Student access page (HTML)
- S3-hosted template URL

**Share with Students:** CloudFormation URL or student access page

---

### Phase 2: Student Environment Deployment (Per Student)

#### 2.1 Student Accesses Deployment Link

1. Student opens CloudFormation quick-deploy URL
2. AWS Console shows pre-configured stack

#### 2.2 Student Provides Parameters

**Required Inputs:**
- **Neptun Code**: 6-character student identifier (e.g., `ABC123`)
- **Task Selection**: Choose from dropdown (`task-01`, `task-02`, `task-03`)

**Pre-configured by Instructor:**
- Evaluation endpoint URL
- Submission endpoint URL
- API key (NoEcho, hidden from student)
- EC2 key pair name

#### 2.3 CloudFormation Stack Creation

**Resources Created:**
```
StudentSecurityGroup (EC2::SecurityGroup)
├─ Port 22: SSH access
├─ Port 6443: Kubernetes API server
└─ Port 30000-32767: NodePort services

StudentInstanceRole (IAM::Role)
└─ AmazonSSMManagedInstanceCore policy

StudentInstanceProfile (IAM::InstanceProfile)

StudentK3sInstance (EC2::Instance)
├─ Ubuntu 22.04 LTS
├─ t3.medium instance type
├─ UserData script for automated setup
└─ Tags: NeptunCode, Task, Name
```

**UserData Execution (~5-10 minutes):**
```bash
1. Update system packages
2. Install AWS CLI v2, curl, wget, jq
3. Install K3s Kubernetes cluster
4. Configure kubectl access for ubuntu user
5. Update kubeconfig with external IP
6. Install Kyverno policy engine
7. Create task-specific namespace
8. Create evaluator service account (cluster-admin)
9. Generate service account token for remote evaluation
10. Create student workspace at /home/ubuntu/k8s-workspace
11. Save configuration files:
    - EVALUATION_ENDPOINT.txt
    - SUBMISSION_ENDPOINT.txt
    - API_KEY.txt
    - student-id.txt (Neptun Code)
    - cluster-endpoint.txt
    - cluster-token.txt
12. Create student-tools scripts:
    - request-evaluation.sh
    - submit-final.sh
13. Create task README with instructions
14. Create welcome message
```

#### 2.4 Student Connects to Environment

**From CloudFormation Outputs Tab:**
- **Public IP**: EC2 instance IP address
- **SSH Command**: `ssh -i vockey.pem ubuntu@<public-ip>`
- **Kubernetes Endpoint**: `https://<public-ip>:6443`

---

### Phase 3: Student Task Completion

#### 3.1 Student Reads Task Requirements

```bash
ssh -i vockey.pem ubuntu@<public-ip>
cd k8s-workspace
cat tasks/task-01/README.md
```

**Task 01 Requirements:**
- Create deployment named `nginx-web` in namespace `task-01`
- Use image `nginx:1.25`
- Set replicas to `3`
- Configure resource limits and requests:
  - CPU limit: 100m, request: 50m
  - Memory limit: 128Mi, request: 64Mi
- Add label `app=nginx-web`
- All pods must be in `Running` state

#### 3.2 Student Creates Solution

```bash
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

# Deploy solution
kubectl apply -f nginx-deployment.yaml

# Verify deployment
kubectl get all -n task-01
kubectl describe deployment nginx-web -n task-01
```

---

### Phase 4: Remote Evaluation (Critical Remote Operation)

#### 4.1 Student Requests Evaluation

```bash
cd student-tools
./request-evaluation.sh task-01
```

#### 4.2 Request Flow

**Student Side:**
```
request-evaluation.sh
├─ Reads configuration files:
│  ├─ EVALUATION_ENDPOINT.txt
│  ├─ API_KEY.txt
│  ├─ student-id.txt
│  ├─ cluster-endpoint.txt
│  └─ cluster-token.txt
├─ Creates JSON payload:
│  {
│    "student_id": "ABC123",
│    "task_id": "task-01",
│    "cluster_endpoint": "https://54.123.45.67:6443",
│    "cluster_token": "eyJhbGciOiJS..."
│  }
└─ Sends HTTP POST with X-API-Key header
```

**Network Traversal:**
```
Student EC2 (Account A)
    ↓ HTTPS POST
    ↓ X-API-Key: <api-key>
    ↓
Lambda Function URL (Account B)
    ↓ Validates API Key
    ↓ Parses Request
    ↓
Evaluation Lambda (evaluator.py)
    ├─ Validates API key in request header
    ├─ Generates evaluation token (UUID)
    ├─ Creates kubeconfig with student cluster credentials
    ├─ Tests connectivity to student cluster
    │  └─ GET https://54.123.45.67:6443/api/v1/namespaces/task-01
    ├─ Evaluates task requirements:
    │  ├─ GET .../deployments/nginx-web
    │  │  ├─ Check deployment exists ✓
    │  │  ├─ Check replicas = 3 ✓
    │  │  ├─ Check image = nginx:1.25 ✓
    │  │  ├─ Check resources set ✓
    │  │  └─ Check labels = app:nginx-web ✓
    │  └─ GET .../pods?labelSelector=app=nginx-web
    │     ├─ Check pod count = 3 ✓
    │     └─ Check all pods Running ✓
    ├─ Calculates score:
    │  ├─ Deployment exists: 20 pts
    │  ├─ Replicas correct: 15 pts
    │  ├─ Image correct: 15 pts
    │  ├─ Resources set: 20 pts
    │  ├─ Labels correct: 10 pts
    │  ├─ Pod count correct: 10 pts
    │  └─ Pods running: 10 pts
    │  Total: 100/100
    └─ Stores results in S3:
       s3://k8s-eval-results/evaluations/ABC123/task-01/<uuid>.json
```

**Response to Student:**
```json
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
```

#### 4.3 Student Reviews Results

- Student can run evaluation **multiple times**
- Each evaluation generates new token
- Student can iterate and improve solution
- Only final submission counts

---

### Phase 5: Final Submission

#### 5.1 Student Submits When Satisfied

```bash
./submit-final.sh task-01
```

**Confirmation Prompt:**
```
WARNING: This will submit your final results for grading.
Make sure you have:
1. Completed the task requirements
2. Run request-evaluation.sh and reviewed the results
3. Made any necessary corrections

Are you sure you want to submit? (yes/no):
```

#### 5.2 Submission Flow

**Student Side:**
```
submit-final.sh
├─ Reads eval-token-task-01.txt (from previous evaluation)
├─ Creates submission payload:
│  {
│    "student_id": "ABC123",
│    "task_id": "task-01",
│    "eval_token": "a1b2c3d4-..."
│  }
└─ Sends HTTP POST with X-API-Key header
```

**Submission Lambda Processing:**
```
Submission Lambda (submission-handler.py)
├─ Validates API key
├─ Verifies evaluation token exists in S3:
│  └─ GET s3://k8s-eval-results/evaluations/ABC123/task-01/<token>.json
├─ Creates official submission record:
│  └─ Original evaluation data + submission_timestamp
├─ Stores in submissions folder:
│  └─ s3://k8s-eval-results/submissions/task-01/ABC123/<timestamp>.json
└─ Returns confirmation
```

**Response:**
```json
{
  "message": "Submission successful",
  "submission_id": "2025-10-21T14:30:00.123456",
  "score": 100,
  "max_score": 100,
  "task_id": "task-01"
}
```

#### 5.3 Cleanup

- Evaluation token file deleted automatically
- Student workspace remains intact
- CloudFormation stack can be deleted when done

---

### Phase 6: Instructor Grade Collection

#### 6.1 List All Submissions

```bash
# In instructor CloudShell
aws s3 ls s3://k8s-eval-results/submissions/task-01/ --recursive

# Output:
# submissions/task-01/ABC123/2025-10-21T14:30:00.123456.json
# submissions/task-01/DEF456/2025-10-21T15:45:00.789012.json
# submissions/task-01/GHI789/2025-10-21T16:20:00.345678.json
```

#### 6.2 Download Submission for Review

```bash
# Download specific submission
aws s3 cp s3://k8s-eval-results/submissions/task-01/ABC123/2025-10-21T14:30:00.123456.json - | jq '.'

# Download all submissions for a task
aws s3 sync s3://k8s-eval-results/submissions/task-01/ ./submissions/
```

#### 6.3 Submission Record Format

```json
{
  "eval_token": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "student_id": "ABC123",
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

---

## Security Model

### Account Isolation

**Student AWS Account:**
- Students have full access to their EC2 instance
- Students can see their cluster credentials
- Students CANNOT access instructor AWS account
- Students CANNOT see Lambda function code
- Students CANNOT access S3 bucket directly

**Instructor AWS Account:**
- Stores all evaluation logic and results
- Lambda functions are code-protected
- S3 bucket restricted to LabRole
- API key provides basic authentication
- Future enhancement: Per-student authentication tokens

### Authentication Flow

```
Request → Lambda checks X-API-Key header
         ├─ No API key → 401 Unauthorized
         ├─ Wrong API key → 401 Unauthorized
         └─ Valid API key → Process request
                           ├─ Validate cluster connectivity
                           ├─ Test cluster credentials
                           └─ Perform evaluation
```

### Data Protection

- **Evaluation Logic**: Hidden in Lambda code (not accessible to students)
- **API Key**: Shared secret, can be rotated by redeploying Lambdas
- **Cluster Tokens**: Student-specific, cannot access other clusters
- **Submissions**: Stored with timestamp for audit trail

---

## Key Features

### Remote Evaluation Capabilities

✅ **Separate AWS Accounts**: Instructor infrastructure isolated from students
✅ **Remote Cluster Access**: Lambda connects to student K3s clusters via API
✅ **No Local Evaluation Code**: Students cannot see or modify evaluation logic
✅ **Centralized Storage**: All results in instructor-controlled S3
✅ **Audit Trail**: Every evaluation and submission timestamped and logged

### Advantages Over Original Framework

| Feature | Original (Local) | New (Remote) |
|---------|-----------------|--------------|
| Evaluation Location | Student EC2 | Instructor Lambda |
| Code Visibility | Student can inspect | Completely hidden |
| Result Storage | Local files | Centralized S3 |
| Grading | Manual collection | Automated collection |
| Audit Trail | None | Full timestamp logs |
| Scalability | One-per-student | Serverless auto-scale |
| Cost | EC2 running time | Pay-per-evaluation |
| Security | Low (local access) | High (remote isolated) |

### Student Experience Improvements

- ✅ One-click CloudFormation deployment
- ✅ Pre-configured environment (K3s, Kyverno, tools)
- ✅ Simple evaluation request scripts
- ✅ Immediate feedback on submissions
- ✅ Multiple evaluation attempts allowed
- ✅ Clear task instructions and requirements

---

## Technology Stack

### Instructor Infrastructure
- **AWS Lambda**: Python 3.11 runtime
  - Evaluation: 512MB, 300s timeout
  - Submission: 256MB, 60s timeout
- **AWS S3**: Result storage with LabRole policies
- **Lambda Function URLs**: Public HTTPS endpoints (auth: NONE + API key)
- **CloudFormation**: Template distribution via S3

### Student Infrastructure
- **AWS EC2**: t3.medium Ubuntu 22.04 LTS
- **K3s**: Lightweight Kubernetes v1.27+
- **Kyverno**: Policy engine v1.10.0
- **Bash Scripts**: Student interaction tools
- **kubectl**: Kubernetes CLI

### Network Communication
- **HTTPS**: All Lambda invocations
- **Kubernetes API**: REST API calls from Lambda
- **Bearer Token Auth**: Service account tokens
- **Insecure TLS Skip**: K3s self-signed certificates

---

## Testing & Validation

### Test Cases

1. **Infrastructure Deployment**
   - ✓ S3 bucket creation
   - ✓ Lambda function deployment
   - ✓ Function URL configuration
   - ✓ API key generation

2. **Student Environment Setup**
   - ✓ CloudFormation stack creation
   - ✓ EC2 instance provisioning
   - ✓ K3s cluster initialization
   - ✓ Service account creation
   - ✓ Student tools configuration

3. **Remote Evaluation**
   - ✓ Cluster connectivity test
   - ✓ Deployment validation
   - ✓ Resource checking
   - ✓ Pod status verification
   - ✓ Score calculation
   - ✓ S3 result storage

4. **Submission Processing**
   - ✓ Token validation
   - ✓ Submission recording
   - ✓ S3 storage
   - ✓ Timestamp accuracy

5. **Security**
   - ✓ API key validation
   - ✓ Unauthorized request rejection
   - ✓ Account isolation
   - ✓ Code protection

---

## Future Enhancements (For UI Integration)

### Planned Improvements

1. **Authentication**
   - Per-student API keys or tokens
   - Neptun Code-based HMAC signing
   - Cluster-based authentication validation

2. **Web UI**
   - Student dashboard for task selection
   - Real-time evaluation results
   - Progress tracking
   - Leaderboard (optional)

3. **Instructor Dashboard**
   - View all submissions
   - Filter by task/student
   - Export grades to CSV
   - Re-evaluate functionality

4. **Enhanced Evaluation**
   - Custom test cases per task
   - Policy-based validation
   - Performance benchmarks
   - Security scanning

5. **Monitoring & Logging**
   - CloudWatch Logs integration
   - Evaluation metrics
   - Error tracking
   - Usage analytics

---

## Thesis Deliverables Checklist

✅ **Analysis**: Reviewed Kubernetes & AWS features, analyzed current framework
✅ **Design**: Multi-component cloud-native application (Lambda, S3, EC2, K3s)
✅ **Remote Architecture**: Separate AWS account, inaccessible to students
✅ **Implementation**: Functional evaluation and submission Lambda functions
✅ **Testing**: End-to-end workflow validation with Task 01
✅ **Feature Parity**: Original framework capabilities maintained
✅ **Improvements**: Centralized storage, security, scalability, audit trail
✅ **Documentation**: Complete workflow, architecture, and security analysis

---

## Conclusion

This remote-controlled Kubernetes assessment framework successfully:

1. **Separates evaluation logic** from student environments
2. **Provides secure remote access** to student clusters for grading
3. **Maintains AWS account isolation** between instructor and students
4. **Offers automated evaluation** with centralized result storage
5. **Scales to handle multiple concurrent students** via serverless Lambda
6. **Preserves educational value** while improving security and manageability

The framework is production-ready for classroom deployment and provides a solid foundation for future UI-based enhancements.
