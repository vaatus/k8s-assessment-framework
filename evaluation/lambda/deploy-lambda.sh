#!/bin/bash
# Deploy updated evaluator Lambda function

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

LAMBDA_FUNCTION_NAME="k8s-evaluator"
ZIP_FILE="lambda-deployment.zip"

echo "========================================"
echo "Deploying Updated Evaluator Lambda"
echo "========================================"
echo ""

echo "1. Creating deployment package..."
# Remove old zip if exists
rm -f "$ZIP_FILE"

# Create zip with evaluator code
zip -r "$ZIP_FILE" evaluator_dynamic.py
echo "   ✅ Created $ZIP_FILE"
echo ""

echo "2. File size:"
ls -lh "$ZIP_FILE"
echo ""

echo "3. Ready to upload to Lambda!"
echo ""
echo "Upload commands (choose one):"
echo ""
echo "   Option A - AWS CLI (from PowerShell in AWS Learner Lab):"
echo "   -------------------------------------------------------"
echo "   aws lambda update-function-code \\"
echo "     --function-name $LAMBDA_FUNCTION_NAME \\"
echo "     --zip-file fileb://evaluation/lambda/$ZIP_FILE"
echo ""
echo "   Option B - AWS Console:"
echo "   -----------------------"
echo "   1. Open Lambda console: https://console.aws.amazon.com/lambda"
echo "   2. Find function: $LAMBDA_FUNCTION_NAME"
echo "   3. Click 'Upload from' > '.zip file'"
echo "   4. Select: $SCRIPT_DIR/$ZIP_FILE"
echo "   5. Click 'Save'"
echo ""
echo "4. After upload, test with:"
echo "   ssh ubuntu@ip-10-0-1-148"
echo "   ~/student-tools/request-evaluation.sh task-03"
echo ""
echo "   Expected: graceful_shutdown: true (if working correctly)"
echo ""
