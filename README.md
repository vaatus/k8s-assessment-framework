# 🎓 Kubernetes Assessment Framework

A complete solution for automated Kubernetes assessment with remote evaluation capabilities. This framework enables instructors to deploy evaluation infrastructure in their AWS account while students work in separate AWS Learner Lab accounts.

## 🌟 Key Features

- ✅ **One-Command Setup** - Single script deploys complete instructor infrastructure
- ✅ **Cross-Account Evaluation** - Instructor and student AWS accounts are completely separate
- ✅ **Remote Assessment** - Lambda functions evaluate student clusters from instructor account
- ✅ **Secure API Authentication** - API key-based authentication for all operations
- ✅ **One-Click Student Deployment** - CloudFormation template with pre-configured endpoints
- ✅ **Automatic Kyverno Integration** - Policy validation built into student environments
- ✅ **Auto-Cleanup** - Student environments shut down after 4 hours
- ✅ **Professional Tools** - Real K3s, Kyverno policies, industry practices

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
├── cloudformation/
│   └── unified-student-template.yaml   # Main CloudFormation template
├── evaluation/lambda/
│   └── evaluator.py                    # Evaluation Lambda function
├── submission/lambda/
│   └── submitter.py                    # Submission Lambda function
├── instructor-tools/
│   ├── deploy-complete-setup.sh        # ⭐ ONE-COMMAND SETUP (run this!)
│   └── view-results.sh                 # View student submissions
├── tasks/
│   ├── task-01/                        # Deploy NGINX Web Application
│   ├── task-02/                        # Service and Ingress Configuration
│   └── task-03/                        # ConfigMaps and Secrets
└── legacy-scripts/                     # Archived old scripts
```

## 🚀 Quick Start

### For Instructors (One-time Setup - 5 Minutes)

Run ONE command:

```bash
cd instructor-tools
./deploy-complete-setup.sh
```

This single script will:
1. ✅ Create S3 buckets (results + templates)
2. ✅ Deploy Lambda functions (evaluation + submission)
3. ✅ Generate API key for authentication
4. ✅ Configure CloudFormation template
5. ✅ Upload template to public S3
6. ✅ Create student landing page
7. ✅ Display student deployment link

You'll get output like:
```
Student Landing Page: https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html
Direct Deploy: https://us-east-1.console.aws.amazon.com/cloudformation/...
```

**Share the landing page URL with your students** - that's it!

### For Students (One-Click Deployment)

1. **Visit landing page** provided by instructor
2. **Click "Deploy My Environment"** button
3. **Enter Neptun Code** (6 characters, e.g., `ABC123`)
4. **Select assigned task** from dropdown
5. **Click "Create Stack"** and wait 5-10 minutes
6. **Get SSH command** from "Outputs" tab
7. **Connect and work**:
   ```bash
   ssh -i ~/Downloads/labsuser.pem ubuntu@<PUBLIC-IP>

   # Welcome message shows you everything
   cat ~/welcome.txt

   # Navigate to workspace
   cd ~/k8s-workspace/tasks/task-01
   cat README.md

   # Create solution
   nano solution.yaml
   kubectl apply -f solution.yaml

   # Request evaluation (can run multiple times)
   ~/student-tools/request-evaluation.sh task-01

   # When satisfied, submit final
   ~/student-tools/submit-final.sh task-01
   ```

## 📋 What Students Get

### Environment Includes:
- ✅ **K3s Cluster**: Lightweight Kubernetes (single-node)
- ✅ **Kyverno**: Policy engine pre-installed and configured
- ✅ **Task Workspace**: `/home/ubuntu/k8s-workspace/` with task files
- ✅ **Evaluation Tools**: Scripts to request evaluation and submit results
- ✅ **Welcome Guide**: Comprehensive instructions in `~/welcome.txt`
- ✅ **Kubectl**: Pre-configured and ready to use
- ✅ **Auto-Cleanup**: Environment deletes after 4 hours

### What's Pre-Configured:
- Service account for remote evaluation
- Cluster API accessible from instructor account
- Evaluation and submission endpoints embedded
- API key authentication built-in
- Git repository cloned with all tasks

## 📊 Available Tasks

### Task 01: Deploy NGINX Web Application
**Objective**: Create a scalable NGINX deployment with resource limits

**What Students Learn**:
- Kubernetes Deployments
- Replica management
- Resource limits (CPU/Memory)
- Labels and selectors

**Evaluation Checks**:
- Deployment exists
- Correct number of replicas (3)
- Resource limits configured
- All pods running healthy

### Task 02: Service and Ingress Configuration
**Objective**: Expose applications using services and ingress

**What Students Learn**:
- ClusterIP vs NodePort vs LoadBalancer
- Service selectors
- Ingress resources
- Path-based routing

**Evaluation Checks**:
- Services created correctly
- Proper port mappings
- Ingress configured
- Endpoints reachable

### Task 03: ConfigMaps and Secrets
**Objective**: Manage configuration and sensitive data

**What Students Learn**:
- ConfigMap creation and usage
- Secret encoding (base64)
- Environment variables
- Volume mounts

**Evaluation Checks**:
- ConfigMap exists
- Secret properly encoded
- Mounted in pods
- Application uses configuration

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

## 🛠️ Viewing Results (Instructors)

### Interactive Results Viewer

```bash
cd instructor-tools
./view-results.sh
```

Options:
1. View all submissions
2. Filter by Neptun Code
3. Filter by Task ID
4. View latest evaluations
5. Download all results (with summary report)

### Direct S3 Access

```bash
# List all submissions
aws s3 ls s3://k8s-eval-results/submissions/ --recursive

# Download specific result
aws s3 cp s3://k8s-eval-results/submissions/ABC123/task-01/final.json -

# Download everything
aws s3 sync s3://k8s-eval-results/ ./results/
```

### Monitor Active Environments

```bash
# List all student stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query 'StackSummaries[?starts_with(StackName, `k8s-student-`)].{Name:StackName,Status:StackStatus,Created:CreationTime}'

# Cleanup specific stack
aws cloudformation delete-stack --stack-name k8s-student-ABC123
```

## 🔧 Customization

### Adding New Tasks

1. Create task directory:
```bash
mkdir tasks/task-04
```

2. Add task files:
```
tasks/task-04/
├── README.md           # Student instructions
├── solution.yaml       # Reference solution
└── policy.yaml         # Kyverno validation policy (optional)
```

3. Update CloudFormation template (`cloudformation/unified-student-template.yaml`):
```yaml
Mappings:
  TaskConfiguration:
    task-04:
      Name: "Your New Task Name"
      Description: "Task description"
      GitHubPath: "tasks/task-04"

Parameters:
  TaskSelection:
    AllowedValues:
      - task-01
      - task-02
      - task-03
      - task-04  # Add this
```

4. Update evaluation Lambda (`evaluation/lambda/evaluator.py`) to handle task-04

5. Redeploy:
```bash
cd instructor-tools
./deploy-complete-setup.sh
```

### Changing Environment Lifetime

Edit `cloudformation/unified-student-template.yaml`:
```bash
# Find line with: echo "sudo shutdown -h +240" | at now
# Change +240 (minutes) to desired duration
# +360 = 6 hours, +480 = 8 hours, etc.
```

Redeploy template after changes.

## 🚨 Troubleshooting

### Student Issues

**"Stack creation failed"**
- Ensure AWS Learner Lab session is active
- Check that `vockey` key pair exists in EC2 console
- Review CloudFormation Events tab for specific error

**"Can't SSH into instance"**
- Wait 1-2 minutes after stack shows CREATE_COMPLETE
- Verify using correct SSH key (labsuser.pem from Learner Lab)
- Check security group allows SSH on port 22

**"Evaluation request fails"**
- Verify K3s is running: `systemctl status k3s`
- Check Kyverno is ready: `kubectl get pods -n kyverno`
- Wait 2-3 minutes after instance boot for all services

**"Unauthorized - Invalid API Key"**
- This means template has wrong API key
- Contact instructor to redeploy template

### Instructor Issues

**"Could not set public bucket policy"**
- This is normal in AWS Learner Lab
- The deploy script handles this automatically
- Bucket-level Block Public Access is disabled separately

**"Lambda deployment fails"**
- Check IAM role exists: `aws iam get-role --role-name LabRole`
- Verify you're in correct region (us-east-1)
- Check Lambda service limits

**"Students can't access template"**
- Test template URL in browser: `https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/unified-student-template.yaml`
- Check bucket policy: `aws s3api get-bucket-policy --bucket k8s-assessment-templates`
- Verify Block Public Access is disabled for bucket

### Debug Commands

```bash
# Check Lambda logs
aws logs tail /aws/lambda/k8s-evaluation-function --follow
aws logs tail /aws/lambda/k8s-submission-function --follow

# Test evaluation endpoint
curl -X POST $(cat instructor-tools/EVALUATION_ENDPOINT.txt) \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $(cat instructor-tools/API_KEY.txt)" \
  -d '{"test": true}'

# Check S3 buckets
aws s3 ls s3://k8s-eval-results/
aws s3 ls s3://k8s-assessment-templates/

# View student K3s status (from student EC2)
systemctl status k3s
kubectl get nodes
kubectl get pods -A
```

## 📚 Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/cloudformation/)
- [AWS Lambda Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/lambda-urls.html)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 🤝 Contributing

This framework is part of a thesis project. Contributions welcome!

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Test your changes with `deploy-complete-setup.sh`
4. Commit changes: `git commit -m 'Add amazing feature'`
5. Push to branch: `git push origin feature/amazing-feature`
6. Open Pull Request

## 📄 License

This project is part of academic work. Please cite appropriately if used in research or teaching.

## 👤 Author

**Taha Samy**
- Thesis: Remote Kubernetes Assessment Framework
- GitHub: [@taha2samy](https://github.com/taha2samy)

## 🙏 Acknowledgments

- Professor's K3s CloudFormation template for architectural inspiration
- AWS Learner Lab for providing educational AWS infrastructure
- Kyverno project for policy validation capabilities
- K3s project for lightweight Kubernetes distribution

---

**Version**: 2.0 (Unified)
**Last Updated**: October 2024
**Status**: ✅ Production Ready

---

## 🚀 Quick Start Reminder

**Instructors**: Run `./instructor-tools/deploy-complete-setup.sh`
**Students**: Visit the landing page URL provided by instructor

That's it! 🎉