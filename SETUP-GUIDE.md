# Kubernetes Assessment Framework - Complete Setup Guide

## Overview
This framework provides a secure, scalable solution for evaluating Kubernetes tasks using two AWS Learner Lab accounts:
- **Instructor Account**: Hosts evaluation and submission infrastructure
- **Student Account**: Kubernetes environment where students complete tasks

## Architecture

```
┌─────────────────────┐    ┌─────────────────────────┐
│   Instructor Acct   │    │    Student Account      │
│                     │    │                         │
│  ┌─────────────────┐│    │ ┌─────────────────────┐ │
│  │ S3 Bucket       ││    │ │ EKS Cluster         │ │
│  │ k8s-eval-results││    │ │ + Kyverno           │ │
│  └─────────────────┘│    │ │ + Student Tasks     │ │
│                     │    │ └─────────────────────┘ │
│  ┌─────────────────┐│    │                         │
│  │ Lambda Functions││    │ ┌─────────────────────┐ │
│  │ - Evaluator     ││◄───┤ │ Student Scripts     │ │
│  │ - Submission    ││    │ │ - request-eval      │ │
│  └─────────────────┘│    │ │ - submit-final      │ │
└─────────────────────┘    │ └─────────────────────┘ │
                           └─────────────────────────┘
```

## Prerequisites

### Both Accounts
- AWS CLI configured
- `jq` installed for JSON parsing
- `kubectl` installed
- Access to AWS Learner Lab environment

### Student Account Additional Requirements
- EKS cluster running
- Kyverno installed
- KUTTL installed (optional, for testing)

## Setup Instructions

### Phase 1: Instructor Account Setup

#### 1.1 Create S3 Bucket
```bash
cd instructor-tools
chmod +x setup-s3-bucket.sh
./setup-s3-bucket.sh
```

#### 1.2 Deploy Evaluation Lambda
```bash
chmod +x deploy-evaluation-lambda.sh
./deploy-evaluation-lambda.sh
```

#### 1.3 Deploy Submission Lambda
```bash
chmod +x deploy-submission-lambda.sh
./deploy-submission-lambda.sh
```

#### 1.4 Get Endpoint URLs
```bash
# Evaluation endpoint
cat EVALUATION_ENDPOINT.txt

# Submission endpoint
cat SUBMISSION_ENDPOINT.txt
```

### Phase 2: Student Account Setup

#### 2.1 Launch EC2 Instance and Install k3s
```bash
# Launch EC2 instance (t3.medium recommended)
# Connect via SSH and run:

# Setup k3s cluster
chmod +x student-tools/setup-k3s-cluster.sh
./student-tools/setup-k3s-cluster.sh

# Configure security group
chmod +x student-tools/configure-ec2-security.sh
./student-tools/configure-ec2-security.sh

# Create service account for evaluation
chmod +x student-tools/create-service-account.sh
./student-tools/create-service-account.sh
```

#### 2.2 Install Kyverno
```bash
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.10.0/install.yaml
```

#### 2.3 Apply Task Policies
```bash
kubectl apply -f policies/task-01-policy.yaml
```

#### 2.4 Setup Student Environment
```bash
# Create student ID file
echo "student-12345" > student-id.txt

# Copy endpoint files from instructor account
# EVALUATION_ENDPOINT.txt
# SUBMISSION_ENDPOINT.txt

# Make scripts executable
chmod +x student-tools/request-evaluation.sh
chmod +x student-tools/submit-final.sh
```

## Task Workflow

### For Students

1. **Read Task Requirements**
   ```bash
   cat tasks/task-01/README.md
   ```

2. **Create Namespace**
   ```bash
   kubectl create namespace task-01
   ```

3. **Complete Task Implementation**
   - Create your Kubernetes manifests
   - Apply them to the cluster
   - Verify everything is working

4. **Request Evaluation**
   ```bash
   cd student-tools
   ./request-evaluation.sh task-01
   ```

5. **Review Results and Submit**
   ```bash
   # If satisfied with results
   ./submit-final.sh task-01
   ```

### For Instructors

1. **View All Submissions**
   ```bash
   aws s3 ls s3://k8s-eval-results/submissions/ --recursive
   ```

2. **Download Specific Submission**
   ```bash
   aws s3 cp s3://k8s-eval-results/submissions/task-01/student-12345/2024-01-15T10:30:00.json ./
   ```

3. **View Evaluation History**
   ```bash
   aws s3 ls s3://k8s-eval-results/evaluations/ --recursive
   ```

## Security Features

### Student Account Isolation
- Students cannot access evaluation logic (runs in instructor Lambda)
- Students cannot modify scoring criteria
- Students can only submit evaluation tokens, not create them
- All evaluation happens remotely via cluster API access

### Instructor Account Protection
- Lambda functions run with minimal LabRole permissions
- S3 bucket has specific access policies
- Evaluation results are immutable once submitted
- Clear audit trail of all submissions

## File Structure

```
k8s-assessment-framework/
├── instructor-tools/           # Instructor-only deployment scripts
│   ├── setup-s3-bucket.sh
│   ├── deploy-evaluation-lambda.sh
│   ├── deploy-submission-lambda.sh
│   └── submission-handler.py
├── evaluation/lambda/          # Lambda function code
│   └── evaluator.py
├── student-tools/              # Student-side scripts
│   ├── request-evaluation.sh
│   └── submit-final.sh
├── tasks/                      # Task definitions
│   └── task-01/
│       ├── README.md
│       ├── solution.yaml       # Instructor reference
│       ├── kuttl-test.yaml
│       └── tests/
├── policies/                   # Kyverno policies
│   └── task-01-policy.yaml
└── SETUP-GUIDE.md
```

## Testing with KUTTL (Optional)

Install KUTTL:
```bash
kubectl krew install kuttl
```

Run tests:
```bash
cd tasks/task-01
kubectl kuttl test --config kuttl-test.yaml
```

## Troubleshooting

### Common Issues

1. **Lambda Timeout**
   - Increase timeout in deploy scripts
   - Check cluster connectivity

2. **Evaluation Token Not Found**
   - Ensure student ran request-evaluation.sh successfully
   - Check S3 bucket permissions

3. **Cluster Connection Failed**
   - Verify kubeconfig is correct
   - Check EKS cluster security groups
   - Ensure service account tokens are valid

4. **Kyverno Policy Violations**
   - Review policy requirements in policies/
   - Check namespace and resource names
   - Validate resource specifications

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/k8s-task-evaluator --follow

# Check S3 bucket contents
aws s3 ls s3://k8s-eval-results --recursive

# Test cluster connectivity
kubectl cluster-info

# Check Kyverno status
kubectl get cpol
kubectl describe cpol task-01-validation
```

## Next Steps

1. Create additional tasks by copying task-01 structure
2. Modify evaluation criteria in evaluator.py
3. Add more sophisticated Kyverno policies
4. Implement automated grading reports
5. Add task time limits and scheduling

## Support

For issues with this framework:
1. Check troubleshooting section
2. Review AWS CloudWatch logs
3. Verify all prerequisites are met
4. Ensure both accounts have proper permissions