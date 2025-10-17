# 🎓 Kubernetes Assessment Framework

A comprehensive, secure, and scalable framework for conducting Kubernetes assessments using AWS infrastructure. This framework enables professors to deploy hands-on Kubernetes tasks that students complete in isolated, pre-configured environments.

## 🌟 Key Features

- ✅ **CloudFormation Quick Deploy** - Students get personal environments with one click
- ✅ **Neptun Code Integration** - Built-in student identification system
- ✅ **Secure Evaluation** - Students cannot access scoring logic or solutions
- ✅ **Auto-scaling Infrastructure** - Supports hundreds of concurrent students
- ✅ **Cost Optimization** - Pay only for active student sessions
- ✅ **Professional Tools** - Real k3s, Kyverno policies, industry practices

## 🏗️ Architecture

```
┌─────────────────────────┐    ┌─────────────────────────────┐
│     Instructor Account  │    │      Student Account        │
│                         │    │                             │
│  ┌─────────────────────┐│    │  ┌─────────────────────────┐│
│  │ S3 Bucket           ││    │  │ CloudFormation Template ││
│  │ k8s-eval-results    ││    │  │ (Quick Deploy Link)     ││
│  └─────────────────────┘│    │  └─────────────────────────┘│
│                         │    │              │               │
│  ┌─────────────────────┐│    │              ▼               │
│  │ Lambda Functions    ││    │  ┌─────────────────────────┐│
│  │ - Evaluator         ││◄───┤  │ Student EC2 + k3s       ││
│  │ - Submission        ││    │  │ - Isolated environment  ││
│  └─────────────────────┘│    │  │ - Pre-configured tools  ││
└─────────────────────────┘    │  └─────────────────────────┘│
                               └─────────────────────────────┘
```

## 📁 Repository Structure

```
k8s-assessment-framework/
├── README.md                           # This comprehensive guide
├── cloudformation/                     # CloudFormation templates and scripts
│   ├── student-quick-deploy.yaml       # Main template for student environments
│   ├── create-quick-deploy-link.sh     # Script to create shareable deployment link
│   └── deploy-multi-student.sh         # Alternative multi-student deployment
├── evaluation/lambda/                  # Evaluation system (instructor-only)
│   ├── evaluator.py                    # Lambda function for task evaluation
│   └── requirements.txt                # Python dependencies
├── instructor-tools/                   # Instructor deployment scripts
│   ├── setup-s3-bucket.sh             # Creates S3 bucket for results
│   ├── deploy-evaluation-lambda.sh     # Deploys evaluation Lambda
│   ├── deploy-submission-lambda.sh     # Deploys submission Lambda
│   └── submission-handler.py           # Lambda function for final submissions
├── policies/                           # Kyverno policy enforcement
│   └── task-01-policy.yaml            # Example policy for task validation
├── student-tools/                      # Student-side scripts (embedded in environments)
│   ├── request-evaluation.sh           # Script to request task evaluation
│   └── submit-final.sh                 # Script to submit final results
├── debug-tools/                        # Manual setup and testing tools
│   ├── manual-k3s-setup.sh            # Manual k3s setup for demos/debugging
│   └── test-student-workflow.sh       # Test complete student workflow
└── tasks/                              # Task definitions and requirements
    └── task-01/
        ├── README.md                   # Task requirements and instructions
        └── solution.yaml               # Reference solution (instructor-only)
```

## 🚀 Quick Start

### For Instructors (One-time Setup)

#### Step 1: Deploy Instructor Infrastructure
```bash
# Clone the repository
git clone <repository-url>
cd k8s-assessment-framework

# Deploy S3 bucket and Lambda functions in instructor account
cd instructor-tools
./setup-s3-bucket.sh
./deploy-evaluation-lambda.sh
./deploy-submission-lambda.sh
```

#### Step 2: Create Student Deployment Link
```bash
# Create the CloudFormation quick deploy link
cd ../cloudformation
./create-quick-deploy-link.sh \
  "$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)" \
  "$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)" \
  "your-keypair-name"
```

#### Step 3: Share with Students
The script will output a CloudFormation link like:
```
https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?templateURL=https://k8s-assessment-templates.s3.amazonaws.com/student-quick-deploy.yaml&stackName=k8s-student-environment
```

### For Students (Simple Deployment)

1. **Click the CloudFormation link** provided by instructor
2. **Enter your Neptun Code** (6 characters, e.g., `ABC123`)
3. **Select your assigned task** from dropdown
4. **Click "Create Stack"** and wait 5-10 minutes
5. **Get SSH details** from "Outputs" tab
6. **Connect and complete task**:
   ```bash
   ssh -i keypair.pem ubuntu@<your-ip>
   cd k8s-workspace
   cat tasks/task-01/README.md
   # Complete task...
   ./student-tools/request-evaluation.sh task-01
   ./student-tools/submit-final.sh task-01
   ```

## 📋 Detailed File Descriptions

### 🔧 CloudFormation Templates

#### `cloudformation/student-quick-deploy.yaml`
**Main CloudFormation template for student environments**
- Creates isolated EC2 instance with k3s cluster
- Installs and configures Kyverno policy engine
- Sets up student workspace with task requirements
- Pre-configures evaluation and submission tools
- Includes auto-cleanup after 4 hours
- Supports Neptun Code identification

#### `cloudformation/create-quick-deploy-link.sh`
**Script to create shareable deployment link**
- Uploads template to S3 bucket with public access
- Pre-configures instructor endpoints in template
- Generates CloudFormation console link for students
- Creates student-friendly deployment page
- Outputs management commands for instructors

#### `cloudformation/deploy-multi-student.sh`
**Alternative deployment for multi-student management**
- Creates centralized registration system
- Uses Lambda for dynamic environment provisioning
- Includes DynamoDB for session tracking
- Provides API endpoints for student registration
- More complex but supports advanced features

### ⚙️ Evaluation System

#### `evaluation/lambda/evaluator.py`
**Core evaluation Lambda function (instructor-only)**
- Receives student cluster credentials securely
- Connects to student k3s clusters remotely
- Evaluates task completion against requirements
- Uses Kubernetes API calls (not kubectl)
- Returns detailed scoring and feedback
- Generates evaluation tokens for submissions

#### `evaluation/lambda/requirements.txt`
**Python dependencies for Lambda**
- `boto3`: AWS SDK for S3 operations
- `PyYAML`: Kubernetes manifest parsing
- `requests`: HTTP client for Kubernetes API
- `urllib3`: HTTP library with SSL support

### 🎯 Instructor Tools

#### `instructor-tools/setup-s3-bucket.sh`
**Creates S3 bucket for storing results**
- Creates `k8s-eval-results` bucket
- Sets up proper IAM policies
- Creates folder structure for evaluations/submissions
- Configures access permissions for Lambda functions

#### `instructor-tools/deploy-evaluation-lambda.sh`
**Deploys the evaluation Lambda function**
- Packages Python code with dependencies
- Creates or updates Lambda function
- Sets up Function URL for student access
- Configures proper timeout and memory settings
- Uses LabRole for execution permissions

#### `instructor-tools/deploy-submission-lambda.sh`
**Deploys the submission Lambda function**
- Creates Lambda for final result submissions
- Validates evaluation tokens before submission
- Stores final results in S3 submissions folder
- Provides audit trail with timestamps

#### `instructor-tools/submission-handler.py`
**Lambda function for processing final submissions**
- Validates evaluation tokens from students
- Prevents duplicate or fraudulent submissions
- Creates permanent submission records
- Links submissions to evaluation results
- Provides confirmation to students

### 📚 Tasks and Policies

#### `tasks/task-01/README.md`
**Example task definition and requirements**
- Clear objectives and specifications
- Step-by-step deployment instructions
- Evaluation criteria and point distribution
- Getting started guide for students
- Submission process explanation

#### `tasks/task-01/solution.yaml`
**Reference solution (instructor-only)**
- Complete working solution for the task
- Proper resource specifications
- Correct labels and configurations
- Should not be accessible to students

#### `policies/task-01-policy.yaml`
**Kyverno policy for task validation**
- Enforces task requirements at deployment time
- Validates resource specifications
- Prevents incorrect configurations
- Provides immediate feedback to students
- Ensures consistency across submissions

### 🎓 Student Tools

#### `student-tools/request-evaluation.sh`
**Script for requesting task evaluation**
- Gathers cluster credentials automatically
- Sends secure request to evaluation Lambda
- Displays detailed results and scoring
- Saves evaluation token for submission
- Can be run multiple times for testing

#### `student-tools/submit-final.sh`
**Script for final result submission**
- Uses evaluation token from previous evaluation
- Confirms submission with user prompt
- Sends final results to instructor system
- Provides submission confirmation
- Cleans up temporary files after success

### 🔧 Debug and Testing Tools

#### `debug-tools/manual-k3s-setup.sh`
**Manual k3s setup for demonstration/debugging**
- Sets up k3s cluster manually on EC2 instance
- Handles all the fixes we discovered (external IP, security, tokens)
- Useful for professor demonstrations
- Provides fallback when CloudFormation isn't available
- Creates all necessary files for student workflow testing

#### `debug-tools/test-student-workflow.sh`
**Complete workflow testing script**
- Tests the entire student evaluation and submission process
- Validates all components are working together
- Useful for verifying setup before demonstrations
- Simulates student actions end-to-end
- Provides detailed feedback on any failures

#### `instructor-tools/test-complete-setup.sh`
**Comprehensive setup validation**
- Tests S3 bucket accessibility
- Validates Lambda function deployments
- Checks endpoint file generation
- Tests Lambda connectivity and responses
- Provides next steps for CloudFormation deployment

## 💰 Cost Structure

### Per Student (4-hour session):
- **EC2 t3.medium**: ~$0.16
- **Lambda executions**: ~$0.01
- **S3 storage**: Negligible
- **Total per student**: ~$0.17

### For 50 students: ~$8.50 total cost

## 🔒 Security Features

### What Students Get:
- ✅ Pre-configured k3s cluster
- ✅ Task requirements and instructions
- ✅ Evaluation and submission tools
- ✅ Isolated personal environment

### What Students Cannot Access:
- ❌ Evaluation logic or Lambda code
- ❌ Scoring criteria and algorithms
- ❌ Reference solutions
- ❌ Other students' environments
- ❌ Instructor infrastructure

## 🛠️ Management Commands

### Monitor Active Sessions
```bash
# View all active student environments
aws ec2 describe-instances --filters "Name=tag:Purpose,Values=k8s-assessment"
```

### View Submissions
```bash
# List all submissions
aws s3 ls s3://k8s-eval-results/submissions/ --recursive

# Download specific submission
aws s3 cp s3://k8s-eval-results/submissions/task-01/ABC123/2024-01-15T10:30:00.json ./
```

### Cleanup
```bash
# Terminate specific student environment
aws cloudformation delete-stack --stack-name k8s-student-environment-ABC123

# Emergency cleanup all
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Purpose,Values=k8s-assessment" --query "Reservations[].Instances[].InstanceId" --output text)
```

## 🔧 Customization

### Adding New Tasks
1. Copy `tasks/task-01/` to `tasks/task-02/`
2. Update `README.md` with new requirements
3. Create corresponding Kyverno policy
4. Modify evaluation logic in `evaluator.py`
5. Update CloudFormation template task list

### Modifying Scoring
Edit the `calculate_score()` function in `evaluation/lambda/evaluator.py`:
```python
def calculate_score(results):
    score = 0
    if results['deployment_exists']:
        score += 20  # Adjust points as needed
    # Add more criteria...
    return score
```

### Changing Session Duration
Update the CloudFormation template parameter:
```yaml
SessionTimeoutHours:
  Type: Number
  Default: 6  # Change from 4 to 6 hours
```

## 🚨 Troubleshooting

### Common Issues

**Student can't connect to cluster:**
- Check security group allows port 6443
- Verify k3s service is running
- Confirm external IP in kubeconfig

**Evaluation fails:**
- Check Lambda logs in CloudWatch
- Verify cluster is accessible from internet
- Ensure service account tokens are valid

**CloudFormation deployment fails:**
- Verify key pair exists in target region
- Check IAM permissions for stack creation
- Review CloudFormation events for details

### Debug Commands
```bash
# Check Lambda logs
aws logs tail /aws/lambda/k8s-task-evaluator --follow

# Test cluster connectivity
curl -k https://<student-ip>:6443/version

# Check Kyverno status
kubectl get cpol
```

## 📈 Scaling Considerations

### For Large Classes (100+ students):
- Use multiple AWS regions to distribute load
- Consider Spot instances for cost savings
- Implement queue system for deployment requests
- Monitor service limits and request increases

### Performance Optimization:
- Cache Docker images in ECR
- Pre-warm Lambda functions
- Use CloudFront for template distribution
- Implement batch operations for management

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create feature branch
3. Test with sample deployment
4. Submit pull request with documentation

### Testing Changes
```bash
# Test instructor setup
cd instructor-tools && ./setup-s3-bucket.sh

# Test student deployment
cd cloudformation && ./create-quick-deploy-link.sh <eval-url> <sub-url> <keypair>

# Verify evaluation workflow
# Deploy test environment and run evaluation
```

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check troubleshooting section above
2. Review AWS CloudWatch logs
3. Verify all prerequisites are met
4. Create GitHub issue with detailed description

## 🎯 Use Cases

### Academic Institutions
- University Kubernetes courses
- DevOps certification programs
- Cloud computing workshops
- Hands-on assessments and exams

### Corporate Training
- Employee upskilling programs
- Kubernetes adoption training
- DevOps team assessments
- Technical interview processes

---

**Ready to deploy? Start with the Quick Start guide above!** 🚀