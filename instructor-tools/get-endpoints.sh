#!/bin/bash
set -e

echo "=== Retrieving Lambda Function URLs ==="

REGION="us-east-1"

# Get Evaluation Lambda URL
echo "Getting Evaluation Lambda URL..."
EVAL_URL=$(aws lambda list-function-url-configs \
    --function-name k8s-task-evaluator \
    --region ${REGION} \
    --query 'FunctionUrlConfigs[0].FunctionUrl' \
    --output text 2>/dev/null || echo "")

if [ "$EVAL_URL" == "None" ] || [ -z "$EVAL_URL" ]; then
    echo "Evaluation Function URL not found. Creating one..."
    EVAL_URL=$(aws lambda create-function-url-config \
        --function-name k8s-task-evaluator \
        --auth-type NONE \
        --region ${REGION} \
        --query 'FunctionUrl' \
        --output text)
fi

# Get Submission Lambda URL
echo "Getting Submission Lambda URL..."
SUB_URL=$(aws lambda list-function-url-configs \
    --function-name k8s-submission-handler \
    --region ${REGION} \
    --query 'FunctionUrlConfigs[0].FunctionUrl' \
    --output text 2>/dev/null || echo "")

if [ "$SUB_URL" == "None" ] || [ -z "$SUB_URL" ]; then
    echo "Submission Function URL not found. Creating one..."
    SUB_URL=$(aws lambda create-function-url-config \
        --function-name k8s-submission-handler \
        --auth-type NONE \
        --region ${REGION} \
        --query 'FunctionUrl' \
        --output text)
fi

# Save URLs to files
echo "$EVAL_URL" > EVALUATION_ENDPOINT.txt
echo "$SUB_URL" > SUBMISSION_ENDPOINT.txt

echo ""
echo "==================================="
echo "✅ Evaluation URL: $EVAL_URL"
echo "✅ Submission URL: $SUB_URL"
echo "==================================="
echo ""
echo "URLs saved to:"
echo "- EVALUATION_ENDPOINT.txt"
echo "- SUBMISSION_ENDPOINT.txt"
echo ""
echo "Share these files with students!"