#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Re-upload CloudFormation Template                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

REGION="us-east-1"
TEMPLATES_BUCKET="k8s-assessment-templates"
TEMPLATE_FILE="unified-student-template.yaml"

# Check if endpoint files exist
if [ ! -f "EVALUATION_ENDPOINT.txt" ] || [ ! -f "SUBMISSION_ENDPOINT.txt" ] || [ ! -f "API_KEY.txt" ]; then
    echo "❌ Error: Endpoint files not found"
    echo "   Run ./deploy-complete-setup.sh first"
    exit 1
fi

EVAL_FUNCTION_URL=$(cat EVALUATION_ENDPOINT.txt)
SUBMIT_FUNCTION_URL=$(cat SUBMISSION_ENDPOINT.txt)
API_KEY=$(cat API_KEY.txt)

echo "This will re-upload the CloudFormation template with current endpoints."
echo ""
echo "Evaluation Endpoint: ${EVAL_FUNCTION_URL:0:50}..."
echo "Submission Endpoint: ${SUBMIT_FUNCTION_URL:0:50}..."
echo "API Key: ${API_KEY:0:8}..."
echo ""

cd ../cloudformation

# Copy template
cp ${TEMPLATE_FILE} ${TEMPLATE_FILE}.tmp

# Update template with endpoints using Python (safer than sed)
python3 << EOF
import re

with open('${TEMPLATE_FILE}.tmp', 'r') as f:
    content = f.read()

# Replace only the endpoint Default values
content = re.sub(
    r"(  EvaluationEndpoint:\n    Type: String\n    Default: )'([^']*)'",
    r"\1'${EVAL_FUNCTION_URL}'",
    content
)
content = re.sub(
    r"(  SubmissionEndpoint:\n    Type: String\n    Default: )'([^']*)'",
    r"\1'${SUBMIT_FUNCTION_URL}'",
    content
)
content = re.sub(
    r"(  ApiKey:\n    Type: String\n    NoEcho: true\n    Default: )'([^']*)'",
    r"\1'${API_KEY}'",
    content
)

with open('${TEMPLATE_FILE}.tmp', 'w') as f:
    f.write(content)
EOF

# Validate template
echo "Validating template..."
if aws cloudformation validate-template --template-body "file://${TEMPLATE_FILE}.tmp" > /dev/null 2>&1; then
    echo "✅ Template is valid"
else
    echo "❌ Template validation failed"
    rm ${TEMPLATE_FILE}.tmp
    exit 1
fi

# Upload to S3
echo "Uploading to S3..."
aws s3 cp ${TEMPLATE_FILE}.tmp "s3://${TEMPLATES_BUCKET}/${TEMPLATE_FILE}" --region ${REGION}

# Cleanup
rm ${TEMPLATE_FILE}.tmp

cd ../instructor-tools

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Template Re-uploaded Successfully! ✅            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Template URL:"
echo "  https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/${TEMPLATE_FILE}"
echo ""
echo "Landing Page:"
echo "  https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/index.html"
echo ""
