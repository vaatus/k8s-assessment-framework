#!/bin/bash
set -e

echo "=== Testing Complete Deployment ==="

echo "1. Testing S3 bucket..."
if aws s3 ls s3://k8s-eval-results >/dev/null 2>&1; then
    echo "✅ S3 bucket accessible"
else
    echo "❌ S3 bucket not accessible"
    exit 1
fi

echo ""
echo "2. Testing Evaluation Lambda..."
if aws lambda get-function --function-name k8s-task-evaluator >/dev/null 2>&1; then
    echo "✅ Evaluation Lambda exists"

    if [ -f "EVALUATION_ENDPOINT.txt" ]; then
        EVAL_URL=$(cat EVALUATION_ENDPOINT.txt)
        echo "✅ Evaluation URL: $EVAL_URL"
    else
        echo "❌ EVALUATION_ENDPOINT.txt not found"
    fi
else
    echo "❌ Evaluation Lambda not found"
fi

echo ""
echo "3. Testing Submission Lambda..."
if aws lambda get-function --function-name k8s-submission-handler >/dev/null 2>&1; then
    echo "✅ Submission Lambda exists"

    if [ -f "SUBMISSION_ENDPOINT.txt" ]; then
        SUB_URL=$(cat SUBMISSION_ENDPOINT.txt)
        echo "✅ Submission URL: $SUB_URL"
    else
        echo "❌ SUBMISSION_ENDPOINT.txt not found"
    fi
else
    echo "❌ Submission Lambda not found"
fi

echo ""
echo "4. Testing Lambda connectivity..."
if [ -f "EVALUATION_ENDPOINT.txt" ]; then
    EVAL_URL=$(cat EVALUATION_ENDPOINT.txt)

    # Test with invalid data to check if Lambda responds
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"test": "connectivity"}' \
        "$EVAL_URL" || echo "CURL_FAILED")

    if [[ "$RESPONSE" == *"error"* ]] || [[ "$RESPONSE" == *"Missing required parameters"* ]]; then
        echo "✅ Evaluation Lambda responding correctly"
    else
        echo "❌ Evaluation Lambda not responding as expected"
        echo "Response: $RESPONSE"
    fi
fi

echo ""
echo "=== Deployment Test Complete ==="
echo ""
echo "Next steps:"
echo "1. Share EVALUATION_ENDPOINT.txt with students"
echo "2. Share SUBMISSION_ENDPOINT.txt with students"
echo "3. Students should set up their EKS cluster"
echo "4. Students should create student-id.txt file"