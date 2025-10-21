#!/bin/bash
set -e

echo "=== Fixing Lambda Function URL Authorization ==="

REGION="us-east-1"
EVAL_FUNCTION="k8s-task-evaluator"
SUB_FUNCTION="k8s-submission-handler"

# Get Evaluation Lambda URL
echo ""
echo "Processing ${EVAL_FUNCTION}..."
EVAL_CONFIG=$(aws lambda get-function-url-config --function-name ${EVAL_FUNCTION} --region ${REGION} 2>/dev/null || echo "")

if [ -z "$EVAL_CONFIG" ]; then
    echo "❌ No Function URL configured for ${EVAL_FUNCTION}"
    exit 1
fi

EVAL_AUTH=$(echo "$EVAL_CONFIG" | grep -o '"AuthType": "[^"]*"' | cut -d'"' -f4)
EVAL_URL=$(echo "$EVAL_CONFIG" | grep -o '"FunctionUrl": "[^"]*"' | cut -d'"' -f4)

echo "✅ Function exists"
echo "Current auth type: ${EVAL_AUTH}"
echo "Function URL: ${EVAL_URL}"

if [ "$EVAL_AUTH" != "NONE" ]; then
    echo "Updating auth type to NONE..."

    # Delete existing Function URL config
    aws lambda delete-function-url-config \
        --function-name ${EVAL_FUNCTION} \
        --region ${REGION}

    echo "Waiting for deletion to complete..."
    sleep 3

    # Recreate with NONE auth
    EVAL_URL=$(aws lambda create-function-url-config \
        --function-name ${EVAL_FUNCTION} \
        --auth-type NONE \
        --region ${REGION} \
        --query 'FunctionUrl' \
        --output text)

    echo "✅ Function URL updated: ${EVAL_URL}"
else
    echo "✅ Already configured with NONE auth type"
fi

# Add resource-based policy for public access
echo "Adding public invoke permission..."
aws lambda add-permission \
    --function-name ${EVAL_FUNCTION} \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null && echo "✅ Permission added" || echo "⚠️  Permission already exists (this is OK)"

# Get Submission Lambda URL
echo ""
echo "Processing ${SUB_FUNCTION}..."
SUB_CONFIG=$(aws lambda get-function-url-config --function-name ${SUB_FUNCTION} --region ${REGION} 2>/dev/null || echo "")

if [ -z "$SUB_CONFIG" ]; then
    echo "❌ No Function URL configured for ${SUB_FUNCTION}"
    exit 1
fi

SUB_AUTH=$(echo "$SUB_CONFIG" | grep -o '"AuthType": "[^"]*"' | cut -d'"' -f4)
SUB_URL=$(echo "$SUB_CONFIG" | grep -o '"FunctionUrl": "[^"]*"' | cut -d'"' -f4)

echo "✅ Function exists"
echo "Current auth type: ${SUB_AUTH}"
echo "Function URL: ${SUB_URL}"

if [ "$SUB_AUTH" != "NONE" ]; then
    echo "Updating auth type to NONE..."

    # Delete existing Function URL config
    aws lambda delete-function-url-config \
        --function-name ${SUB_FUNCTION} \
        --region ${REGION}

    echo "Waiting for deletion to complete..."
    sleep 3

    # Recreate with NONE auth
    SUB_URL=$(aws lambda create-function-url-config \
        --function-name ${SUB_FUNCTION} \
        --auth-type NONE \
        --region ${REGION} \
        --query 'FunctionUrl' \
        --output text)

    echo "✅ Function URL updated: ${SUB_URL}"
else
    echo "✅ Already configured with NONE auth type"
fi

# Add resource-based policy for public access
echo "Adding public invoke permission..."
aws lambda add-permission \
    --function-name ${SUB_FUNCTION} \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null && echo "✅ Permission added" || echo "⚠️  Permission already exists (this is OK)"

echo ""
echo "=== Update Complete ==="
echo ""
echo "Evaluation URL: ${EVAL_URL}"
echo "Submission URL: ${SUB_URL}"
echo ""

# Save URLs to files
echo "${EVAL_URL}" > EVALUATION_ENDPOINT.txt
echo "${SUB_URL}" > SUBMISSION_ENDPOINT.txt

echo "URLs saved to:"
echo "  - EVALUATION_ENDPOINT.txt"
echo "  - SUBMISSION_ENDPOINT.txt"
echo ""
echo "✅ Lambda functions are now publicly accessible with NONE auth"
