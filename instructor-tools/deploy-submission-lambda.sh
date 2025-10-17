#!/bin/bash
set -e

echo "=== Deploying Submission Handler Lambda ==="

# Variables
FUNCTION_NAME="k8s-submission-handler"
REGION="us-east-1"

# Get LabRole ARN
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)

if [ -z "$ROLE_ARN" ]; then
    echo "ERROR: Could not find LabRole"
    exit 1
fi

echo "Using Role ARN: ${ROLE_ARN}"

# Package Lambda
echo "Creating deployment package..."
zip -r submission-lambda-package.zip submission-handler.py

# Check if function exists
FUNCTION_EXISTS=$(aws lambda list-functions --region ${REGION} --query "Functions[?FunctionName=='${FUNCTION_NAME}'].FunctionName" --output text)

if [ -n "$FUNCTION_EXISTS" ]; then
    echo "Function exists, updating..."
    aws lambda update-function-code \
      --function-name ${FUNCTION_NAME} \
      --zip-file fileb://submission-lambda-package.zip \
      --region ${REGION}
else
    echo "Creating new function..."
    aws lambda create-function \
      --function-name ${FUNCTION_NAME} \
      --runtime python3.11 \
      --role "${ROLE_ARN}" \
      --handler submission-handler.lambda_handler \
      --zip-file fileb://submission-lambda-package.zip \
      --timeout 60 \
      --memory-size 256 \
      --region ${REGION}

    echo "Waiting for function to be active..."
    aws lambda wait function-active --function-name ${FUNCTION_NAME} --region ${REGION}
fi

# Check if Function URL exists
FUNCTION_URL_EXISTS=$(aws lambda list-function-url-configs --function-name ${FUNCTION_NAME} --region ${REGION} --query 'FunctionUrlConfigs[0].FunctionUrl' --output text 2>/dev/null || echo "")

if [ "$FUNCTION_URL_EXISTS" == "None" ] || [ -z "$FUNCTION_URL_EXISTS" ]; then
    echo "Creating Function URL..."
    SUBMISSION_URL=$(aws lambda create-function-url-config \
      --function-name ${FUNCTION_NAME} \
      --auth-type NONE \
      --region ${REGION} \
      --query 'FunctionUrl' \
      --output text)
else
    SUBMISSION_URL=$FUNCTION_URL_EXISTS
    echo "Function URL already exists"
fi

echo ""
echo "==================================="
echo "Submission Lambda URL: ${SUBMISSION_URL}"
echo "==================================="
echo ""
echo "Save this URL - students will use it to submit final results"

# Save URL to file
echo "${SUBMISSION_URL}" > SUBMISSION_ENDPOINT.txt

echo "URL saved to SUBMISSION_ENDPOINT.txt"
echo ""
echo "Deployment complete!"