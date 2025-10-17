#!/bin/bash
set -e

echo "=== Deploying Evaluation Lambda ==="

# Variables
FUNCTION_NAME="k8s-task-evaluator"
REGION="us-east-1"
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole"

# Package Lambda
cd evaluation/lambda
zip -r lambda-package.zip evaluator.py

# Create Lambda function
aws lambda create-function \
  --function-name ${FUNCTION_NAME} \
  --runtime python3.11 \
  --role ${ROLE_ARN} \
  --handler evaluator.lambda_handler \
  --zip-file fileb://lambda-package.zip \
  --timeout 300 \
  --memory-size 512 \
  --region ${REGION}

# Create Function URL for easy invocation
FUNCTION_URL=$(aws lambda create-function-url-config \
  --function-name ${FUNCTION_NAME} \
  --auth-type NONE \
  --region ${REGION} \
  --query 'FunctionUrl' \
  --output text)

echo "Lambda Function URL: ${FUNCTION_URL}"
echo "Save this URL - students will use it to request evaluations"

# Save URL to file
echo ${FUNCTION_URL} > ../../EVALUATION_ENDPOINT.txt

cd ../..