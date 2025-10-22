# Quick Reference Card

## Instructor Quick Start

```bash
# ONE-COMMAND SETUP
cd instructor-tools
./deploy-complete-setup.sh

# VIEW RESULTS
./view-results.sh

# CHECK ENDPOINTS
cat EVALUATION_ENDPOINT.txt
cat SUBMISSION_ENDPOINT.txt
cat API_KEY.txt
```

## Student Quick Start

1. Visit landing page URL (from instructor)
2. Click "Deploy My Environment"
3. Enter Neptun Code (6 characters)
4. Select task
5. Wait 5-10 minutes
6. SSH: `ssh -i labsuser.pem ubuntu@<PUBLIC-IP>`
7. Evaluate: `~/student-tools/request-evaluation.sh task-01`
8. Submit: `~/student-tools/submit-final.sh task-01`

## Repository Structure

```
k8s-assessment-framework/
├── cloudformation/
│   └── unified-student-template.yaml   # Main template
├── instructor-tools/
│   ├── deploy-complete-setup.sh        # ⭐ RUN THIS
│   └── view-results.sh                 # View results
├── evaluation/lambda/
│   └── evaluator.py                    # Evaluation Lambda
├── tasks/
│   ├── task-01/                        # Task files
│   ├── task-02/
│   └── task-03/
└── legacy-scripts/                     # Old scripts (archived)
```

## Common Commands

### Instructor

```bash
# Deploy infrastructure
cd instructor-tools && ./deploy-complete-setup.sh

# View submissions
./view-results.sh

# Test evaluation endpoint
curl -X POST $(cat EVALUATION_ENDPOINT.txt) \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $(cat API_KEY.txt)" \
  -d '{"test": true}'

# List student stacks
aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE

# Download all results
aws s3 sync s3://k8s-eval-results/ ./results/

# Delete student stack
aws cloudformation delete-stack --stack-name k8s-student-ABC123

# Check Lambda logs
aws logs tail /aws/lambda/k8s-evaluation-function --follow
```

### Student (inside EC2)

```bash
# View welcome message
cat ~/welcome.txt

# Navigate to task
cd ~/k8s-workspace/tasks/task-01

# Read instructions
cat README.md

# Apply solution
kubectl apply -f solution.yaml

# Check status
kubectl get all
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Request evaluation
~/student-tools/request-evaluation.sh task-01

# Submit final
~/student-tools/submit-final.sh task-01

# Check Kyverno policies
kubectl get cpol
kubectl get policyreport -A
```

## URLs

### S3 Buckets
- Results (private): `s3://k8s-eval-results/`
- Templates (public): `s3://k8s-assessment-templates/`

### Lambda Function Names
- Evaluation: `k8s-evaluation-function`
- Submission: `k8s-submission-function`

### Student Landing Page
`https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html`

## Troubleshooting

### Template not accessible
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket k8s-assessment-templates

# Check Block Public Access
aws s3api get-public-access-block --bucket k8s-assessment-templates
```

### Lambda deployment fails
```bash
# Check IAM role
aws iam get-role --role-name LabRole

# Check Lambda functions
aws lambda list-functions | grep k8s
```

### Student environment fails
```bash
# Check CloudFormation events
aws cloudformation describe-stack-events --stack-name k8s-student-ABC123

# Check EC2 instance
aws ec2 describe-instances --filters "Name=tag:NeptunCode,Values=ABC123"
```

### Evaluation fails
```bash
# From student EC2
systemctl status k3s
kubectl get pods -A
kubectl get nodes

# Check service account
kubectl get serviceaccount evaluator-sa
kubectl get secret evaluator-sa-token -o yaml
```

## File Locations

### Instructor Tools
- Setup script: `instructor-tools/deploy-complete-setup.sh`
- Results viewer: `instructor-tools/view-results.sh`
- Endpoints: `instructor-tools/*.txt`

### CloudFormation
- Template: `cloudformation/unified-student-template.yaml`

### Lambda Functions
- Evaluator: `evaluation/lambda/evaluator.py`
- Submitter: `submission/lambda/submitter.py`

### Student Tools (on EC2)
- Evaluation: `~/student-tools/request-evaluation.sh`
- Submission: `~/student-tools/submit-final.sh`
- Cluster info: `~/.kube-assessment/cluster-info.json`
- Welcome: `~/welcome.txt`

## API Authentication

All requests require API key in header:
```bash
-H "X-API-Key: your-api-key-here"
```

API key is:
- Generated during setup
- Stored in `instructor-tools/API_KEY.txt`
- Embedded in student scripts automatically

## Default Values

- Region: `us-east-1`
- Instance type: `t3.medium`
- Key pair: `vockey` (AWS Learner Lab)
- Environment lifetime: 4 hours (240 minutes)
- K3s version: Latest stable
- Kyverno version: 1.10.0

## Cost Estimate

Per student (4-hour session):
- EC2 t3.medium: ~$0.16
- Lambda: ~$0.01
- S3: Negligible
- **Total: ~$0.17 per student**

For 50 students: ~$8.50 total

## Support

- Documentation: `README.md`
- Setup guide: `UNIFIED_SETUP_SUMMARY.md`
- This reference: `QUICK_REFERENCE.md`
- Testing guide: `TESTING_GUIDE.md`

## Version Info

- Version: 2.0 (Unified)
- Status: Production Ready
- Last Updated: October 2024
