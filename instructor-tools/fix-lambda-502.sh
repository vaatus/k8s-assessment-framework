#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Fix Lambda 502 Error - Redeploy with Dependencies    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

EVAL_FUNCTION_NAME="k8s-evaluation-function"
REGION="us-east-1"

# Check if we need API key
if [ ! -f "API_KEY.txt" ]; then
    echo "❌ Error: API_KEY.txt not found"
    echo "   Run ./deploy-complete-setup.sh first"
    exit 1
fi

API_KEY=$(cat API_KEY.txt)
RESULTS_BUCKET="k8s-eval-results"

echo "This will redeploy the evaluation Lambda with all dependencies."
echo "This fixes the 502 error caused by missing Python packages (PyYAML, requests, etc.)"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Package evaluation Lambda WITH dependencies
echo ""
echo "=== Packaging Lambda with Dependencies ==="
cd ../evaluation/lambda

if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found"
    exit 1
fi

echo "Installing Python dependencies..."
pip install -r requirements.txt -t /tmp/lambda-package --quiet

echo "Copying Lambda function..."
cp evaluator.py /tmp/lambda-package/

echo "Creating deployment package..."
cd /tmp/lambda-package
zip -r /tmp/evaluator-fixed.zip . -q
cd - > /dev/null

echo "✅ Package created: $(du -h /tmp/evaluator-fixed.zip | cut -f1)"

# Update Lambda function
cd ../../instructor-tools

echo ""
echo "=== Updating Lambda Function ==="
aws lambda update-function-code \
    --function-name ${EVAL_FUNCTION_NAME} \
    --zip-file fileb:///tmp/evaluator-fixed.zip \
    --region ${REGION}

echo ""
echo "Waiting for Lambda to update..."
sleep 5

# Also update environment variables to be sure
echo "Updating environment variables..."
aws lambda update-function-configuration \
    --function-name ${EVAL_FUNCTION_NAME} \
    --environment "Variables={S3_BUCKET=${RESULTS_BUCKET},API_KEY=${API_KEY}}" \
    --region ${REGION} > /dev/null

echo ""
echo "Waiting for configuration update..."
sleep 5

# Cleanup
rm -rf /tmp/lambda-package /tmp/evaluator-fixed.zip

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  Lambda Fixed! ✅                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "The evaluation Lambda has been redeployed with all dependencies."
echo ""
echo "Test it now:"
echo "  ./test-complete-deployment.sh"
echo ""
echo "Or test directly:"
echo "  ./debug-lambda.sh"
echo ""
