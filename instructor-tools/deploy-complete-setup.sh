#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Kubernetes Assessment Framework - Complete Instructor Setup ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

REGION="us-east-1"
RESULTS_BUCKET="k8s-eval-results"
TEMPLATES_BUCKET="k8s-assessment-templates"
TEMPLATE_FILE="unified-student-template.yaml"
LOG_FILE="deployment-$(date +%Y%m%d-%H%M%S).log"

# Create log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "📝 Deployment log: $LOG_FILE"
echo ""

# Reuse existing API key if available, otherwise generate new one
if [ -f "API_KEY.txt" ]; then
    API_KEY=$(cat API_KEY.txt)
    echo "✅ Using existing API key"
else
    API_KEY=$(openssl rand -hex 16)
    echo "✅ Generated new API key"
fi

# Check if we're in the correct directory
if [ ! -f "deploy-complete-setup.sh" ]; then
    echo "❌ Error: Please run this script from the instructor-tools directory"
    exit 1
fi

echo ""
echo "This script will set up the Kubernetes assessment framework:"
echo "  • Create S3 buckets (results and templates)"
echo "  • Build and upload Docker images (test-runner, kvstore)"
echo "  • Deploy Lambda functions with dynamic evaluator"
echo "  • Configure CloudFormation template"
echo "  • Generate student deployment link"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Setup cancelled."
    exit 0
fi

# ============================================================================
# Step 1: Create S3 Buckets
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/5: Creating S3 Buckets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create results bucket (private)
if aws s3 ls "s3://${RESULTS_BUCKET}" 2>/dev/null >/dev/null; then
    echo "✅ Results bucket exists: ${RESULTS_BUCKET}"
else
    echo "⏳ Creating results bucket..."
    aws s3 mb "s3://${RESULTS_BUCKET}" --region ${REGION} >/dev/null
    echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/evaluations/.placeholder" 2>/dev/null
    echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/submissions/.placeholder" 2>/dev/null
    echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/tasks/.placeholder" 2>/dev/null
    echo "✅ Results bucket created: ${RESULTS_BUCKET}"
fi

# Create templates bucket (public)
if aws s3 ls "s3://${TEMPLATES_BUCKET}" 2>/dev/null >/dev/null; then
    echo "✅ Templates bucket exists: ${TEMPLATES_BUCKET}"
else
    echo "⏳ Creating templates bucket..."
    aws s3 mb "s3://${TEMPLATES_BUCKET}" --region ${REGION} >/dev/null
    echo "✅ Templates bucket created: ${TEMPLATES_BUCKET}"
fi

# Enable public access for templates bucket
echo "⏳ Configuring public access..."
aws s3api put-public-access-block \
    --bucket ${TEMPLATES_BUCKET} \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" \
    2>/dev/null

# Apply public bucket policy
cat > /tmp/public-bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${TEMPLATES_BUCKET}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket ${TEMPLATES_BUCKET} --policy file:///tmp/public-bucket-policy.json 2>/dev/null
rm -f /tmp/public-bucket-policy.json
echo "✅ Public access configured"

# ============================================================================
# Step 2: Build and Upload Docker Images
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/5: Building and Uploading Docker Images"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if Docker is available
if command -v docker &> /dev/null; then
    echo "✅ Docker detected"
    read -p "Build and upload Docker images? (yes/no) [default: yes]: " BUILD_IMAGES

    if [ -z "$BUILD_IMAGES" ] || [ "$BUILD_IMAGES" == "yes" ]; then
        if [ -f "build-and-upload-images.sh" ]; then
            echo "⏳ Building images (see log for details)..."
            CONFIRM=yes bash build-and-upload-images.sh >/dev/null 2>&1
            echo "✅ Images built and uploaded to S3"
        else
            echo "⚠️  build-and-upload-images.sh not found"
        fi
    else
        echo "⏭️  Skipping image build"
    fi
else
    echo "⚠️  Docker not found - skipping image build"
    echo "   Students will need pre-loaded images for HTTP testing"
fi

# ============================================================================
# Step 3: Deploy Lambda Functions
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/5: Deploying Lambda Functions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Package evaluation Lambda with dynamic evaluator
cd ../evaluation/lambda

echo "⏳ Packaging evaluation Lambda (dynamic evaluator)..."
rm -rf /tmp/lambda-package /tmp/evaluator.zip 2>/dev/null || true

if [ -f "requirements.txt" ]; then
    mkdir -p /tmp/lambda-package
    pip install -r requirements.txt -t /tmp/lambda-package --quiet --no-cache-dir 2>&1 | grep -v "already satisfied" || true

    # Always use dynamic evaluator
    cp evaluator_dynamic.py /tmp/lambda-package/evaluator.py

    cd /tmp/lambda-package
    zip -r /tmp/evaluator.zip . -q
    cd - > /dev/null
    rm -rf /tmp/lambda-package

    PACKAGE_SIZE=$(du -h /tmp/evaluator.zip | cut -f1)
    echo "✅ Lambda package created (${PACKAGE_SIZE})"
else
    echo "❌ requirements.txt not found"
    exit 1
fi

cd ../../instructor-tools

# Create or update evaluation Lambda function
EVAL_FUNCTION_NAME="k8s-evaluation-function"
if aws lambda get-function --function-name ${EVAL_FUNCTION_NAME} --region ${REGION} 2>/dev/null >/dev/null; then
    echo "⏳ Updating evaluation Lambda..."
    aws lambda update-function-code \
        --function-name ${EVAL_FUNCTION_NAME} \
        --zip-file fileb:///tmp/evaluator.zip \
        --region ${REGION} >/dev/null
else
    echo "⏳ Creating evaluation Lambda..."
    aws lambda create-function \
        --function-name ${EVAL_FUNCTION_NAME} \
        --runtime python3.11 \
        --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole \
        --handler evaluator.lambda_handler \
        --zip-file fileb:///tmp/evaluator.zip \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={S3_BUCKET=${RESULTS_BUCKET},API_KEY=${API_KEY},TEST_RUNNER_IMAGE=test-runner:latest}" \
        --region ${REGION} >/dev/null
fi

# Create function URL
EVAL_FUNCTION_URL=$(aws lambda create-function-url-config \
    --function-name ${EVAL_FUNCTION_NAME} \
    --auth-type NONE \
    --region ${REGION} \
    --query 'FunctionUrl' \
    --output text 2>/dev/null || \
    aws lambda get-function-url-config \
    --function-name ${EVAL_FUNCTION_NAME} \
    --region ${REGION} \
    --query 'FunctionUrl' \
    --output text)

aws lambda add-permission \
    --function-name ${EVAL_FUNCTION_NAME} \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null || true

echo "✅ Evaluation Lambda deployed"

# Package submission Lambda
cd ../submission/lambda
echo "⏳ Packaging submission Lambda..."
rm -rf /tmp/submitter.zip 2>/dev/null || true
zip -r /tmp/submitter.zip submitter.py -q
echo "✅ Submission Lambda packaged"

cd ../../instructor-tools

# Create or update submission Lambda function
SUBMIT_FUNCTION_NAME="k8s-submission-function"
if aws lambda get-function --function-name ${SUBMIT_FUNCTION_NAME} --region ${REGION} 2>/dev/null >/dev/null; then
    echo "⏳ Updating submission Lambda..."
    aws lambda update-function-code \
        --function-name ${SUBMIT_FUNCTION_NAME} \
        --zip-file fileb:///tmp/submitter.zip \
        --region ${REGION} >/dev/null
else
    echo "⏳ Creating submission Lambda..."
    aws lambda create-function \
        --function-name ${SUBMIT_FUNCTION_NAME} \
        --runtime python3.11 \
        --role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole \
        --handler submitter.lambda_handler \
        --zip-file fileb:///tmp/submitter.zip \
        --timeout 300 \
        --memory-size 512 \
        --environment "Variables={S3_BUCKET=${RESULTS_BUCKET},API_KEY=${API_KEY}}" \
        --region ${REGION} >/dev/null
fi

# Create function URL
SUBMIT_FUNCTION_URL=$(aws lambda create-function-url-config \
    --function-name ${SUBMIT_FUNCTION_NAME} \
    --auth-type NONE \
    --region ${REGION} \
    --query 'FunctionUrl' \
    --output text 2>/dev/null || \
    aws lambda get-function-url-config \
    --function-name ${SUBMIT_FUNCTION_NAME} \
    --region ${REGION} \
    --query 'FunctionUrl' \
    --output text)

aws lambda add-permission \
    --function-name ${SUBMIT_FUNCTION_NAME} \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null || true

echo "✅ Submission Lambda deployed"

# Clean up
rm -f /tmp/evaluator.zip /tmp/submitter.zip

# Save endpoints to files
echo "${EVAL_FUNCTION_URL}" > EVALUATION_ENDPOINT.txt
echo "${SUBMIT_FUNCTION_URL}" > SUBMISSION_ENDPOINT.txt
echo "${API_KEY}" > API_KEY.txt
chmod 600 API_KEY.txt

# ============================================================================
# Step 4: Configure CloudFormation Template
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/5: Configuring CloudFormation Template"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd ../cloudformation

# Update template with endpoints and API key
echo "⏳ Injecting Lambda endpoints into template..."
cp ${TEMPLATE_FILE} ${TEMPLATE_FILE}.tmp

python3 << EOF
import re

with open('${TEMPLATE_FILE}.tmp', 'r') as f:
    content = f.read()

# Replace Default values for endpoints and API key
content = re.sub(
    r'(EvaluationEndpoint:\s+Type:\s+String\s+Default:\s+)\'\'',
    r"\1'${EVAL_FUNCTION_URL}'",
    content
)
content = re.sub(
    r'(SubmissionEndpoint:\s+Type:\s+String\s+Default:\s+)\'\'',
    r"\1'${SUBMIT_FUNCTION_URL}'",
    content
)
content = re.sub(
    r'(ApiKey:\s+Type:\s+String\s+NoEcho:\s+true\s+Default:\s+)\'\'',
    r"\1'${API_KEY}'",
    content
)

with open('${TEMPLATE_FILE}.tmp', 'w') as f:
    f.write(content)
EOF

# Upload template to S3
echo "⏳ Uploading template to S3..."
aws s3 cp ${TEMPLATE_FILE}.tmp "s3://${TEMPLATES_BUCKET}/${TEMPLATE_FILE}" --region ${REGION} 2>/dev/null
rm ${TEMPLATE_FILE}.tmp
echo "✅ CloudFormation template configured"

# ============================================================================
# Step 5: Generate Student Deployment Link
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5/5: Generating Student Landing Page"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TEMPLATE_URL="https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/${TEMPLATE_FILE}"
QUICK_DEPLOY_URL="https://${REGION}.console.aws.amazon.com/cloudformation/home?region=${REGION}#/stacks/create/review?templateURL=${TEMPLATE_URL}&stackName=k8s-student-environment"

# Create HTML landing page
cat > student-deploy-page.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Assessment - Quick Deploy</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 900px;
            margin: 40px auto;
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        .logo {
            font-size: 4em;
            margin-bottom: 20px;
        }
        h1 {
            color: #2d3748;
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #718096;
            font-size: 1.3em;
        }
        .deploy-button {
            display: block;
            width: 350px;
            margin: 40px auto;
            padding: 20px 40px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 15px;
            text-align: center;
            font-size: 1.4em;
            font-weight: bold;
            transition: all 0.3s ease;
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        .deploy-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 25px rgba(102, 126, 234, 0.6);
        }
        .instructions {
            background: #f7fafc;
            border-radius: 15px;
            padding: 30px;
            margin: 30px 0;
        }
        .instructions h3 {
            color: #2d3748;
            margin-bottom: 20px;
            font-size: 1.5em;
        }
        .step {
            margin: 20px 0;
            padding: 15px 20px;
            background: white;
            border-radius: 10px;
            border-left: 5px solid #667eea;
        }
        .step strong {
            color: #667eea;
        }
        .warning {
            background: #fff5f5;
            border: 2px solid #fc8181;
            border-radius: 10px;
            padding: 20px;
            margin: 30px 0;
            color: #c53030;
        }
        .warning strong {
            font-size: 1.2em;
        }
        .tasks .task {
            background: white;
            padding: 15px 20px;
            margin: 15px 0;
            border-radius: 10px;
            border-left: 5px solid #48bb78;
        }
        .tasks .task strong {
            color: #48bb78;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🎓</div>
            <h1>Kubernetes Assessment Framework</h1>
            <p class="subtitle">Deploy your personal K3s environment in AWS</p>
        </div>

        <a href="${QUICK_DEPLOY_URL}" class="deploy-button" target="_blank">
            🚀 Deploy My Environment
        </a>

        <div class="instructions">
            <h3>📋 Quick Start Guide</h3>

            <div class="step">
                <strong>Step 1:</strong> Click the "Deploy My Environment" button above
            </div>

            <div class="step">
                <strong>Step 2:</strong> Sign in to your AWS Learner Lab account
            </div>

            <div class="step">
                <strong>Step 3:</strong> In CloudFormation, enter your <strong>6-character Neptun Code</strong> (e.g., ABC123)
            </div>

            <div class="step">
                <strong>Step 4:</strong> Select your assigned task from the dropdown menu
            </div>

            <div class="step">
                <strong>Step 5:</strong> Click "Create Stack" and wait 5-10 minutes
            </div>

            <div class="step">
                <strong>Step 6:</strong> Find your SSH connection details in the "Outputs" tab
            </div>

            <div class="step">
                <strong>Step 7:</strong> Connect via SSH and start working on your task!
            </div>
        </div>

        <div class="warning">
            <strong>⚠️ Important Notices:</strong>
            <ul style="margin: 15px 0 0 20px; line-height: 1.8;">
                <li>Your environment will <strong>auto-delete after 4 hours</strong></li>
                <li>Save your work regularly</li>
                <li>Only one environment allowed per Neptun Code</li>
                <li>Submit your results before the deadline</li>
                <li>Make sure your AWS Learner Lab session is active</li>
            </ul>
        </div>

        <div class="instructions">
            <h3>🔧 What You'll Get</h3>
            <ul style="margin: 15px 0 0 20px; line-height: 2;">
                <li>✅ Personal K3s Kubernetes cluster on EC2</li>
                <li>✅ Pre-configured development environment</li>
                <li>✅ Kyverno policy engine for validation</li>
                <li>✅ Task-specific workspace and instructions</li>
                <li>✅ Evaluation and submission tools</li>
                <li>✅ SSH access with your AWS key pair</li>
            </ul>
        </div>

        <div class="instructions tasks">
            <h3>📚 Available Tasks</h3>
            <div class="task">
                <strong>Task 01:</strong> NGINX Web Deployment<br>
                <small style="color: #718096;">Create a deployment with proper resource limits and labels</small>
            </div>
            <div class="task">
                <strong>Task 02:</strong> StatefulSet with Persistent Storage<br>
                <small style="color: #718096;">Deploy a key-value store with persistent volumes</small>
            </div>
            <div class="task">
                <strong>Task 03:</strong> Health Probes and Graceful Shutdown<br>
                <small style="color: #718096;">Multi-service application with liveness and startup probes</small>
            </div>
        </div>

        <div class="instructions">
            <h3>🛠️ Workflow</h3>
            <ol style="margin: 15px 0 0 20px; line-height: 2;">
                <li>Read task instructions: <code>cat ~/k8s-workspace/tasks/task-XX/README.md</code></li>
                <li>Create your Kubernetes manifests</li>
                <li>Apply your solution: <code>kubectl apply -f solution.yaml</code></li>
                <li>Request evaluation: <code>~/student-tools/request-evaluation.sh task-XX</code></li>
                <li>Review results and iterate</li>
                <li>Submit final: <code>~/student-tools/submit-final.sh task-XX</code></li>
            </ol>
        </div>
    </div>
</body>
</html>
EOF

# Upload landing page to S3
echo "⏳ Uploading landing page to S3..."
aws s3 cp student-deploy-page.html "s3://${TEMPLATES_BUCKET}/index.html" --region ${REGION} 2>/dev/null
LANDING_PAGE_URL="https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/index.html"
rm student-deploy-page.html
echo "✅ Landing page created"

cd ../instructor-tools

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete! ✅                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Resources Created:"
echo "   • S3 Buckets: ${RESULTS_BUCKET}, ${TEMPLATES_BUCKET}"
echo "   • Lambda Functions: Evaluation, Submission (dynamic evaluator)"
echo "   • CloudFormation Template: Configured and uploaded"
echo "   • Student Landing Page: Deployed"
echo ""
echo "🌐 Student Access:"
echo "   Landing Page: ${LANDING_PAGE_URL}"
echo ""
echo "🔑 API Key: ${API_KEY}"
echo "   (Saved securely to: API_KEY.txt)"
echo ""
echo "📝 Files Created:"
echo "   • API_KEY.txt (chmod 600)"
echo "   • EVALUATION_ENDPOINT.txt"
echo "   • SUBMISSION_ENDPOINT.txt"
echo "   • ${LOG_FILE}"
echo ""
echo "🎯 Next Steps:"
echo "   1. Share landing page URL with students: ${LANDING_PAGE_URL}"
echo "   2. Monitor submissions: ./view-results.sh"
echo "   3. Upload task specs (if modified): ./upload-task-specs.sh"
echo ""
echo "📋 Detailed logs saved to: ${LOG_FILE}"
echo ""
