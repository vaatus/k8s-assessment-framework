#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Lambda Function Debugging Tool                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if endpoint files exist
if [ ! -f "EVALUATION_ENDPOINT.txt" ]; then
    echo "❌ Error: EVALUATION_ENDPOINT.txt not found"
    exit 1
fi

EVAL_ENDPOINT=$(cat EVALUATION_ENDPOINT.txt)
EVAL_FUNCTION="k8s-evaluation-function"

echo "Evaluation Function: $EVAL_FUNCTION"
echo "Endpoint: ${EVAL_ENDPOINT:0:50}..."
echo ""

# Check Lambda function configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Checking Lambda Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CONFIG=$(aws lambda get-function-configuration --function-name $EVAL_FUNCTION 2>&1)

if echo "$CONFIG" | grep -q "error\|Error"; then
    echo "❌ Error getting Lambda configuration:"
    echo "$CONFIG"
    exit 1
fi

echo "Runtime: $(echo "$CONFIG" | jq -r '.Runtime' 2>/dev/null || echo "unknown")"
echo "Handler: $(echo "$CONFIG" | jq -r '.Handler' 2>/dev/null || echo "unknown")"
echo "Timeout: $(echo "$CONFIG" | jq -r '.Timeout' 2>/dev/null || echo "unknown") seconds"
echo "Memory: $(echo "$CONFIG" | jq -r '.MemorySize' 2>/dev/null || echo "unknown") MB"
echo ""

# Check environment variables
echo "Environment Variables:"
HAS_S3=$(echo "$CONFIG" | jq -r '.Environment.Variables.S3_BUCKET // "not set"' 2>/dev/null)
HAS_API_KEY=$(echo "$CONFIG" | jq -r '.Environment.Variables.API_KEY // "not set"' 2>/dev/null)
echo "  S3_BUCKET: $HAS_S3"
echo "  API_KEY: ${HAS_API_KEY:0:8}... (length: ${#HAS_API_KEY})"
echo ""

# Check recent Lambda errors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Checking Recent Lambda Logs (last 5 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

LOG_GROUP="/aws/lambda/$EVAL_FUNCTION"

# Check if log group exists
if ! aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" 2>/dev/null | grep -q "$LOG_GROUP"; then
    echo "⚠️  No logs found yet (function may not have been invoked)"
else
    echo "Fetching recent logs..."
    LOGS=$(aws logs tail "$LOG_GROUP" --since 5m --format short 2>/dev/null | tail -30)

    if [ -n "$LOGS" ]; then
        echo "$LOGS"
    else
        echo "⚠️  No recent logs in the last 5 minutes"
    fi
fi

echo ""

# Check Lambda code/dependencies
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Checking Lambda Deployment Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CODE_SIZE=$(echo "$CONFIG" | jq -r '.CodeSize // "unknown"' 2>/dev/null)
echo "Code Size: $CODE_SIZE bytes"

LAST_MODIFIED=$(echo "$CONFIG" | jq -r '.LastModified // "unknown"' 2>/dev/null)
echo "Last Modified: $LAST_MODIFIED"
echo ""

# Test Lambda directly (bypass Function URL)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Testing Lambda Directly (with test event)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "API_KEY.txt" ]; then
    API_KEY=$(cat API_KEY.txt)

    TEST_PAYLOAD='{
        "headers": {
            "X-API-Key": "'"$API_KEY"'"
        },
        "body": "{\"test\": true, \"neptun_code\": \"TEST01\", \"task_id\": \"test\"}"
    }'

    echo "Invoking Lambda function directly..."
    RESPONSE=$(aws lambda invoke \
        --function-name "$EVAL_FUNCTION" \
        --payload "$TEST_PAYLOAD" \
        --cli-binary-format raw-in-base64-out \
        /tmp/lambda-response.json 2>&1)

    echo "Invoke Response:"
    echo "$RESPONSE"
    echo ""

    if [ -f /tmp/lambda-response.json ]; then
        echo "Lambda Output:"
        cat /tmp/lambda-response.json | jq '.' 2>/dev/null || cat /tmp/lambda-response.json
        rm /tmp/lambda-response.json
    fi
else
    echo "⚠️  API_KEY.txt not found, skipping direct test"
fi

echo ""

# Common issues and fixes
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Common Issues and Fixes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If you see 502 errors:"
echo "  1. Lambda code has syntax error → Check logs above"
echo "  2. Missing dependencies (boto3, etc) → Check deployment package"
echo "  3. Lambda timeout → Check if timeout is sufficient (300s recommended)"
echo "  4. Handler name mismatch → Should be 'evaluator.lambda_handler'"
echo "  5. Runtime mismatch → Should be python3.11 or python3.9+"
echo ""
echo "To fix:"
echo "  1. Check logs above for specific error"
echo "  2. Run: ./deploy-complete-setup.sh (redeploy Lambda)"
echo "  3. Check ../evaluation/lambda/evaluator.py for syntax errors"
echo ""

echo "For more details, run:"
echo "  aws logs tail /aws/lambda/$EVAL_FUNCTION --follow"
echo ""
