#!/bin/bash
set -e

echo "=== Deploying Evaluation Lambda ==="

# Variables
FUNCTION_NAME="k8s-task-evaluator"
REGION="us-east-1"

# Get LabRole ARN
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

if [ -z "$ROLE_ARN" ]; then
    echo "ERROR: Could not find LabRole"
    exit 1
fi

echo "Using Role ARN: ${ROLE_ARN}"

# Navigate to lambda directory
cd ../evaluation/lambda

# Package Lambda
echo "Creating deployment package..."
zip -r lambda-package.zip evaluator.py

# Check if function exists
FUNCTION_EXISTS=$(aws lambda list-functions --region ${REGION} --query "Functions[?FunctionName=='${FUNCTION_NAME}'].FunctionName" --output text)

if [ -n "$FUNCTION_EXISTS" ]; then
    echo "Function exists, updating..."
    aws lambda update-function-code \
      --function-name ${FUNCTION_NAME} \
      --zip-file fileb://lambda-package.zip \
      --region ${REGION}
else
    echo "Creating new function..."
    aws lambda create-function \
      --function-name ${FUNCTION_NAME} \
      --runtime python3.11 \
      --role "${ROLE_ARN}" \
      --handler evaluator.lambda_handler \
      --zip-file fileb://lambda-package.zip \
      --timeout 300 \
      --memory-size 512 \
      --region ${REGION}
    
    echo "Waiting for function to be active..."
    aws lambda wait function-active --function-name ${FUNCTION_NAME} --region ${REGION}
fi

# Get or create Function URL
echo "Checking for Function URL..."
FUNCTION_URL=$(aws lambda list-function-url-configs \
    --function-name ${FUNCTION_NAME} \
    --region ${REGION} \
    --query 'FunctionUrlConfigs[0].FunctionUrl' \
    --output text 2>/dev/null || echo "")

if [ "$FUNCTION_URL" == "None" ] || [ -z "$FUNCTION_URL" ] || [ "$FUNCTION_URL" == "null" ]; then
    echo "Creating Function URL..."
    FUNCTION_URL=$(aws lambda create-function-url-config \
      --function-name ${FUNCTION_NAME} \
      --auth-type NONE \
      --region ${REGION} \
      --query 'FunctionUrl' \
      --output text)
    echo "Function URL created: ${FUNCTION_URL}"
else
    echo "Function URL already exists: ${FUNCTION_URL}"
fi

echo ""
echo "==================================="
echo "Lambda Function URL: ${FUNCTION_URL}"
echo "==================================="
echo ""
echo "Save this URL - students will use it to request evaluations"

# Save URL to file
cd ../..
echo "${FUNCTION_URL}" > EVALUATION_ENDPOINT.txt

echo "URL saved to EVALUATION_ENDPOINT.txt"
echo ""
echo "Deployment complete!"