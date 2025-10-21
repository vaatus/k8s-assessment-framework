#!/bin/bash
set -e

echo "=== Fixing Lambda Function URL Authorization ==="

REGION="us-east-1"
EVAL_FUNCTION="k8s-task-evaluator"
SUB_FUNCTION="k8s-submission-handler"

# Function to update Lambda URL auth
update_lambda_auth() {
    local FUNCTION_NAME=$1
    echo ""
    echo "Processing ${FUNCTION_NAME}..."

    # Check if function exists
    FUNCTION_EXISTS=$(aws lambda get-function --function-name ${FUNCTION_NAME} --region ${REGION} 2>/dev/null || echo "")

    if [ -z "$FUNCTION_EXISTS" ]; then
        echo "❌ Function ${FUNCTION_NAME} does not exist"
        return 1
    fi

    echo "✅ Function exists"

    # Get current Function URL config
    CURRENT_CONFIG=$(aws lambda get-function-url-config --function-name ${FUNCTION_NAME} --region ${REGION} 2>/dev/null || echo "")

    if [ -z "$CURRENT_CONFIG" ]; then
        echo "❌ No Function URL configured"
        return 1
    fi

    CURRENT_AUTH=$(echo "$CURRENT_CONFIG" | grep -o '"AuthType": "[^"]*"' | cut -d'"' -f4)
    FUNCTION_URL=$(echo "$CURRENT_CONFIG" | grep -o '"FunctionUrl": "[^"]*"' | cut -d'"' -f4)

    echo "Current auth type: ${CURRENT_AUTH}"
    echo "Function URL: ${FUNCTION_URL}"

    if [ "$CURRENT_AUTH" == "NONE" ]; then
        echo "✅ Already configured with NONE auth type"
        return 0
    fi

    echo "Updating auth type to NONE..."

    # Delete existing Function URL config
    aws lambda delete-function-url-config \
        --function-name ${FUNCTION_NAME} \
        --region ${REGION}

    echo "Waiting for deletion to complete..."
    sleep 3

    # Recreate with NONE auth
    NEW_URL=$(aws lambda create-function-url-config \
        --function-name ${FUNCTION_NAME} \
        --auth-type NONE \
        --region ${REGION} \
        --query 'FunctionUrl' \
        --output text)

    echo "✅ Function URL updated: ${NEW_URL}"
    echo "${NEW_URL}"
}

# Update Evaluation Lambda
EVAL_URL=$(update_lambda_auth ${EVAL_FUNCTION})
if [ $? -ne 0 ]; then
    echo "Failed to update ${EVAL_FUNCTION}"
    exit 1
fi

# Update Submission Lambda
SUB_URL=$(update_lambda_auth ${SUB_FUNCTION})
if [ $? -ne 0 ]; then
    echo "Failed to update ${SUB_FUNCTION}"
    exit 1
fi

echo ""
echo "=== Update Complete ==="
echo ""
echo "Updated URLs:"
echo "Evaluation: ${EVAL_URL}"
echo "Submission: ${SUB_URL}"
echo ""

# Save URLs to files
EVAL_URL_CLEAN=$(echo "${EVAL_URL}" | tail -1)
SUB_URL_CLEAN=$(echo "${SUB_URL}" | tail -1)

echo "${EVAL_URL_CLEAN}" > EVALUATION_ENDPOINT.txt
echo "${SUB_URL_CLEAN}" > SUBMISSION_ENDPOINT.txt

echo "URLs saved to:"
echo "  - EVALUATION_ENDPOINT.txt"
echo "  - SUBMISSION_ENDPOINT.txt"
echo ""
echo "✅ Lambda functions are now publicly accessible with NONE auth"
