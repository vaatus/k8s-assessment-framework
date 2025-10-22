#!/bin/bash
set -e

echo "=== Prepare CloudFormation Template for Student Distribution ==="
echo ""
echo "Since AWS Learner Lab blocks public S3 access, students will need to"
echo "copy the CloudFormation template manually to their accounts."
echo ""

TEMPLATE_FILE="student-quick-deploy.yaml"
OUTPUT_DIR="student-distribution"

# Create distribution directory
mkdir -p ${OUTPUT_DIR}

# Download the configured template from S3 (with embedded endpoints)
echo "Downloading configured template from S3..."
aws s3 cp s3://k8s-assessment-templates/${TEMPLATE_FILE} ${OUTPUT_DIR}/${TEMPLATE_FILE} --region us-east-1

echo "✅ Template downloaded to: ${OUTPUT_DIR}/${TEMPLATE_FILE}"
echo ""

# Create instructions for students
cat > ${OUTPUT_DIR}/STUDENT_INSTRUCTIONS.md << 'EOF'
# Kubernetes Assessment Framework - Student Setup

## Prerequisites
- AWS Learner Lab account (active session)
- SSH key pair named `vockey` in your AWS account (should be auto-created in Learner Lab)

## Deployment Steps

### Step 1: Upload Template to Your AWS Account

1. Log into your **AWS Learner Lab** account
2. Open **AWS CloudShell** (click the CloudShell icon in the top navigation bar)
3. In CloudShell, create a directory:
   ```bash
   mkdir -p ~/k8s-assessment
   cd ~/k8s-assessment
   ```

4. Create the template file:
   ```bash
   nano student-quick-deploy.yaml
   ```

5. Copy the entire contents of the `student-quick-deploy.yaml` file (provided by your instructor) and paste it into the nano editor
6. Save and exit: Press `Ctrl+X`, then `Y`, then `Enter`

### Step 2: Deploy Your Environment

Run the following command in CloudShell:

```bash
aws cloudformation create-stack \
    --stack-name k8s-student-<YOUR-NEPTUN-CODE> \
    --template-body file://student-quick-deploy.yaml \
    --parameters \
      ParameterKey=NeptunCode,ParameterValue=<YOUR-NEPTUN-CODE> \
      ParameterKey=TaskSelection,ParameterValue=task-01 \
      ParameterKey=KeyPairName,ParameterValue=vockey \
    --capabilities CAPABILITY_IAM \
    --region us-east-1
```

**Replace `<YOUR-NEPTUN-CODE>` with your actual 6-character Neptun code (e.g., ABC123)**

### Step 3: Wait for Deployment

The deployment takes 5-10 minutes. Check status:

```bash
aws cloudformation describe-stacks \
    --stack-name k8s-student-<YOUR-NEPTUN-CODE> \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus' \
    --output text
```

Wait until it shows: `CREATE_COMPLETE`

### Step 4: Get Connection Details

```bash
aws cloudformation describe-stacks \
    --stack-name k8s-student-<YOUR-NEPTUN-CODE> \
    --region us-east-1 \
    --query 'Stacks[0].Outputs'
```

Look for the `PublicIP` in the output.

### Step 5: SSH into Your Environment

Download your SSH key from AWS Learner Lab, then connect:

```bash
ssh -i ~/Downloads/labsuser.pem ubuntu@<PUBLIC-IP>
```

### Step 6: Start Working on Your Task

Once connected to the EC2 instance:

```bash
# Check the welcome message
cat ~/welcome.txt

# Navigate to workspace
cd ~/k8s-workspace

# Read task instructions
cat tasks/task-01/README.md

# Create your solution
nano task-01-solution.yaml
kubectl apply -f task-01-solution.yaml

# Request evaluation
cd student-tools
./request-evaluation.sh task-01

# When satisfied with results, submit
./submit-final.sh task-01
```

## Important Notes

- Your environment will auto-delete after 4 hours
- Save your work regularly
- You can run evaluation multiple times
- Only submit when you're confident in your solution

## Troubleshooting

### SSH Connection Refused
- Wait 1-2 minutes after stack creation completes
- Verify you're using the correct SSH key (labsuser.pem from Learner Lab)

### CloudFormation Stack Failed
- Check the CloudFormation console for error details
- Ensure you have an active Learner Lab session
- Verify the `vockey` key pair exists in EC2 console

### Need Help?
Contact your instructor with:
- Your Neptun Code
- The error message
- CloudFormation stack status
EOF

echo "✅ Student instructions created: ${OUTPUT_DIR}/STUDENT_INSTRUCTIONS.md"
echo ""

# Create a README for instructors
cat > ${OUTPUT_DIR}/INSTRUCTOR_README.md << 'EOF'
# Instructor Guide - Distributing CloudFormation Template

## Distribution Methods

Due to AWS Learner Lab restrictions on public S3 access, use one of these methods:

### Method 1: Learning Management System (Recommended)
1. Upload `student-quick-deploy.yaml` to your LMS (Moodle, Canvas, etc.)
2. Upload `STUDENT_INSTRUCTIONS.md` as well
3. Students download both files

### Method 2: GitHub Repository
1. Create a public GitHub repository
2. Upload `student-quick-deploy.yaml`
3. Share the raw file URL with students
4. Students can download directly:
   ```bash
   curl -O https://raw.githubusercontent.com/<your-repo>/main/student-quick-deploy.yaml
   ```

### Method 3: Email/Direct Share
1. Email the template file to students
2. Include the student instructions
3. Students upload to their CloudShell

### Method 4: Live Demo
1. During class, demonstrate the template creation
2. Students follow along and create the file in their CloudShell
3. Paste the template content directly

## Verification

After distribution, verify one student can successfully:
1. Upload the template to CloudShell
2. Deploy the stack
3. Connect via SSH
4. Complete the task
5. Request evaluation
6. Submit results

You should see their submission in:
```bash
aws s3 ls s3://k8s-eval-results/submissions/
```

## Template Updates

If you need to update the template:
1. Modify `student-quick-deploy.yaml` in the repo
2. Run `./create-quick-deploy-link.sh` to update S3
3. Run this script again to create new distribution
4. Re-distribute to students

## Support

Common student issues:
- **Template upload errors**: Have them use `nano` instead of copy-paste
- **Stack creation fails**: Check they have an active Learner Lab session
- **SSH connection fails**: Wait 1-2 minutes, verify SSH key
- **Evaluation fails**: Check Lambda endpoints are still active
EOF

echo "✅ Instructor guide created: ${OUTPUT_DIR}/INSTRUCTOR_README.md"
echo ""

# Create a deployment script for students
cat > ${OUTPUT_DIR}/deploy-stack.sh << 'EOF'
#!/bin/bash
# Student Stack Deployment Script

echo "=== Kubernetes Assessment - Stack Deployment ==="
echo ""

# Prompt for Neptun Code
read -p "Enter your Neptun Code (6 characters, e.g., ABC123): " NEPTUN_CODE

# Validate Neptun Code
if [[ ! "$NEPTUN_CODE" =~ ^[A-Za-z0-9]{6}$ ]]; then
    echo "❌ Error: Neptun Code must be exactly 6 alphanumeric characters"
    exit 1
fi

# Prompt for Task
echo ""
echo "Available tasks:"
echo "  1. task-01 - Deploy NGINX Web Application"
echo "  2. task-02 - Service and Ingress Configuration"
echo "  3. task-03 - ConfigMaps and Secrets"
echo ""
read -p "Enter task number (1-3): " TASK_NUM

case $TASK_NUM in
    1) TASK="task-01" ;;
    2) TASK="task-02" ;;
    3) TASK="task-03" ;;
    *)
        echo "❌ Error: Invalid task number"
        exit 1
        ;;
esac

STACK_NAME="k8s-student-${NEPTUN_CODE}"

echo ""
echo "Deploying your environment..."
echo "  Neptun Code: ${NEPTUN_CODE}"
echo "  Task: ${TASK}"
echo "  Stack Name: ${STACK_NAME}"
echo ""

# Deploy stack
aws cloudformation create-stack \
    --stack-name "${STACK_NAME}" \
    --template-body file://student-quick-deploy.yaml \
    --parameters \
      ParameterKey=NeptunCode,ParameterValue="${NEPTUN_CODE}" \
      ParameterKey=TaskSelection,ParameterValue="${TASK}" \
      ParameterKey=KeyPairName,ParameterValue=vockey \
    --capabilities CAPABILITY_IAM \
    --region us-east-1

if [ $? -eq 0 ]; then
    echo "✅ Stack creation initiated successfully!"
    echo ""
    echo "Waiting for stack to complete (this takes 5-10 minutes)..."
    echo ""

    aws cloudformation wait stack-create-complete \
        --stack-name "${STACK_NAME}" \
        --region us-east-1

    if [ $? -eq 0 ]; then
        echo "✅ Stack created successfully!"
        echo ""
        echo "Getting connection details..."
        PUBLIC_IP=$(aws cloudformation describe-stacks \
            --stack-name "${STACK_NAME}" \
            --region us-east-1 \
            --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' \
            --output text)

        echo ""
        echo "=== Your Environment is Ready! ==="
        echo ""
        echo "Public IP: ${PUBLIC_IP}"
        echo ""
        echo "Connect via SSH:"
        echo "  ssh -i ~/Downloads/labsuser.pem ubuntu@${PUBLIC_IP}"
        echo ""
        echo "Or from CloudShell:"
        echo "  ssh -i ~/.ssh/id_rsa ubuntu@${PUBLIC_IP}"
        echo ""
    else
        echo "❌ Stack creation failed. Check CloudFormation console for details."
        exit 1
    fi
else
    echo "❌ Failed to initiate stack creation"
    exit 1
fi
EOF

chmod +x ${OUTPUT_DIR}/deploy-stack.sh

echo "✅ Student deployment script created: ${OUTPUT_DIR}/deploy-stack.sh"
echo ""

echo "=========================================="
echo "✅ Distribution Package Complete!"
echo "=========================================="
echo ""
echo "Directory: ${OUTPUT_DIR}/"
echo ""
echo "Files created:"
echo "  1. student-quick-deploy.yaml     - CloudFormation template"
echo "  2. STUDENT_INSTRUCTIONS.md       - Step-by-step guide for students"
echo "  3. INSTRUCTOR_README.md          - Distribution guide for you"
echo "  4. deploy-stack.sh               - Automated deployment script"
echo ""
echo "Next Steps:"
echo "  1. Review the files in ${OUTPUT_DIR}/"
echo "  2. Choose a distribution method (see INSTRUCTOR_README.md)"
echo "  3. Share the template and instructions with students"
echo ""
echo "Recommended: Upload the entire ${OUTPUT_DIR}/ folder to your LMS"
echo "=========================================="
