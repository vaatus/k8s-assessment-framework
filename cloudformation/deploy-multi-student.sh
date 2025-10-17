#!/bin/bash
set -e

echo "=== Deploying Multi-Student Kubernetes Assessment Environment ==="

# Configuration
STACK_NAME="k8s-assessment-multi-student"
TEMPLATE_FILE="multi-student-environment.yaml"
REGION="us-east-1"

# Check parameters
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <evaluation-endpoint> <submission-endpoint> <key-pair-name> [max-students] [session-timeout-hours]"
    echo ""
    echo "Example:"
    echo "$0 \\"
    echo "  'https://abc123.lambda-url.us-east-1.on.aws/' \\"
    echo "  'https://def456.lambda-url.us-east-1.on.aws/' \\"
    echo "  'my-keypair' \\"
    echo "  50 \\"
    echo "  4"
    echo ""
    echo "Parameters:"
    echo "  evaluation-endpoint: Lambda evaluation URL from instructor account"
    echo "  submission-endpoint: Lambda submission URL from instructor account"
    echo "  key-pair-name: EC2 Key Pair name (without .pem extension)"
    echo "  max-students: Maximum concurrent students (default: 50)"
    echo "  session-timeout-hours: Auto-cleanup timeout in hours (default: 4)"
    echo ""
    echo "Note: Make sure you have the evaluation and submission Lambda functions"
    echo "      deployed in your instructor account first!"
    exit 1
fi

EVALUATION_ENDPOINT="$1"
SUBMISSION_ENDPOINT="$2"
KEY_PAIR_NAME="$3"
MAX_STUDENTS="${4:-50}"
SESSION_TIMEOUT="${5:-4}"

echo "Configuration:"
echo "  Evaluation Endpoint: ${EVALUATION_ENDPOINT}"
echo "  Submission Endpoint: ${SUBMISSION_ENDPOINT}"
echo "  Key Pair: ${KEY_PAIR_NAME}"
echo "  Max Students: ${MAX_STUDENTS}"
echo "  Session Timeout: ${SESSION_TIMEOUT} hours"
echo "  Stack Name: ${STACK_NAME}"

# Validate key pair exists
echo ""
echo "Validating EC2 Key Pair..."
aws ec2 describe-key-pairs --key-names ${KEY_PAIR_NAME} --region ${REGION} > /dev/null
echo "✅ Key pair '${KEY_PAIR_NAME}' found"

# Validate template
echo ""
echo "Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://${TEMPLATE_FILE} \
    --region ${REGION} > /dev/null
echo "✅ Template is valid"

# Check if stack already exists
echo ""
echo "Checking for existing stack..."
if aws cloudformation describe-stacks --stack-name ${STACK_NAME} --region ${REGION} > /dev/null 2>&1; then
    echo "⚠️  Stack '${STACK_NAME}' already exists"
    read -p "Do you want to update it? (yes/no): " UPDATE_CONFIRM
    if [ "$UPDATE_CONFIRM" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
    DEPLOY_ACTION="update"
else
    DEPLOY_ACTION="create"
fi

# Deploy stack
echo ""
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file ${TEMPLATE_FILE} \
    --stack-name ${STACK_NAME} \
    --parameter-overrides \
        EvaluationEndpoint="${EVALUATION_ENDPOINT}" \
        SubmissionEndpoint="${SUBMISSION_ENDPOINT}" \
        KeyPairName="${KEY_PAIR_NAME}" \
        MaxStudents="${MAX_STUDENTS}" \
        SessionTimeoutHours="${SESSION_TIMEOUT}" \
        InstanceType="t3.medium" \
        TaskList="task-01,task-02" \
    --capabilities CAPABILITY_IAM \
    --region ${REGION}

echo ""
echo "=== Stack Deployment Complete ==="

# Get stack outputs
echo ""
echo "Getting stack outputs..."
REGISTRATION_URL=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} \
    --query 'Stacks[0].Outputs[?OutputKey==`StudentRegistrationUrl`].OutputValue' \
    --output text)

SESSIONS_TABLE=$(aws cloudformation describe-stacks \
    --stack-name ${STACK_NAME} \
    --region ${REGION} \
    --query 'Stacks[0].Outputs[?OutputKey==`DynamoDBTable`].OutputValue' \
    --output text)

echo ""
echo "=== Multi-Student Environment Ready ==="
echo ""
echo "🌐 Student Registration URL:"
echo "   ${REGISTRATION_URL}"
echo ""
echo "📊 Management Information:"
echo "   DynamoDB Table: ${SESSIONS_TABLE}"
echo "   Max Students: ${MAX_STUDENTS}"
echo "   Session Timeout: ${SESSION_TIMEOUT} hours"
echo "   Auto-cleanup: Every 15 minutes"
echo ""
echo "🎓 For Students:"
echo "   1. Visit: ${REGISTRATION_URL}"
echo "   2. Enter their Neptun Code (6 characters)"
echo "   3. Click 'Get Environment'"
echo "   4. Wait 5-10 minutes for setup"
echo "   5. SSH into their assigned instance"
echo "   6. Complete tasks in k8s-workspace"
echo ""
echo "👨‍🏫 For Instructors:"
echo "   • Monitor sessions: aws dynamodb scan --table-name ${SESSIONS_TABLE}"
echo "   • View submissions: aws s3 ls s3://k8s-eval-results/submissions/ --recursive"
echo "   • Cleanup all: aws cloudformation delete-stack --stack-name ${STACK_NAME}"
echo ""

# Create web interface with correct API endpoint
echo "📱 Creating student web interface..."
mkdir -p web-interface-configured
sed "s|REPLACE_WITH_LAMBDA_URL|${REGISTRATION_URL}|g" web-interface/index.html > web-interface-configured/index.html

echo "   Web interface created: web-interface-configured/index.html"
echo "   You can host this HTML file on any web server or S3 bucket"
echo ""

# Create management scripts
echo "🛠️  Creating management scripts..."

cat > manage-students.sh << EOF
#!/bin/bash
# Management script for student environments

SESSIONS_TABLE="${SESSIONS_TABLE}"
REGION="${REGION}"

case "\$1" in
    "list")
        echo "=== Active Student Sessions ==="
        aws dynamodb scan --table-name \${SESSIONS_TABLE} --region \${REGION} \\
            --filter-expression "#status = :status" \\
            --expression-attribute-names '{"#status": "status"}' \\
            --expression-attribute-values '{":status": {"S": "active"}}' \\
            --query 'Items[].{NeptunCode:neptun_code.S,InstanceIP:instance_ip.S,ExpiresAt:expires_at_readable.S}' \\
            --output table
        ;;
    "cleanup-all")
        echo "=== Cleaning Up All Sessions ==="
        aws dynamodb scan --table-name \${SESSIONS_TABLE} --region \${REGION} \\
            --filter-expression "#status IN (:active, :init)" \\
            --expression-attribute-names '{"#status": "status"}' \\
            --expression-attribute-values '{":active": {"S": "active"}, ":init": {"S": "initializing"}}' \\
            --query 'Items[].instance_id.S' --output text | xargs -r aws ec2 terminate-instances --instance-ids
        echo "All instances terminated"
        ;;
    "submissions")
        echo "=== Recent Submissions ==="
        aws s3 ls s3://k8s-eval-results/submissions/ --recursive --human-readable
        ;;
    *)
        echo "Usage: \$0 {list|cleanup-all|submissions}"
        echo ""
        echo "Commands:"
        echo "  list         - Show active student sessions"
        echo "  cleanup-all  - Terminate all student instances"
        echo "  submissions  - Show recent submissions"
        ;;
esac
EOF

chmod +x manage-students.sh

echo "   Management script: ./manage-students.sh"
echo "   Usage: ./manage-students.sh {list|cleanup-all|submissions}"
echo ""

echo "🔗 Quick Test:"
echo "   curl -X POST ${REGISTRATION_URL} \\"
echo "        -H 'Content-Type: application/json' \\"
echo "        -d '{\"action\": \"register\", \"neptun_code\": \"TEST01\"}'"
echo ""

echo "✅ Multi-Student Environment Deployment Complete!"
echo ""
echo "⚠️  Important Notes:"
echo "   • Students environments auto-expire after ${SESSION_TIMEOUT} hours"
echo "   • Monitor costs - each student uses 1 EC2 instance"
echo "   • Use ./manage-students.sh to monitor and cleanup"
echo "   • Share the registration URL with your students"