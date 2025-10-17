#!/bin/bash
set -e

echo "=== Testing Complete Setup ==="

echo "1. Checking S3 bucket..."
if aws s3 ls s3://k8s-eval-results >/dev/null 2>&1; then
    echo "✅ S3 bucket accessible"
else
    echo "❌ S3 bucket not accessible"
    echo "Run: ./setup-s3-bucket.sh"
    exit 1
fi

echo ""
echo "2. Checking Evaluation Lambda..."
if aws lambda get-function --function-name k8s-task-evaluator >/dev/null 2>&1; then
    echo "✅ Evaluation Lambda exists"

    if [ -f "EVALUATION_ENDPOINT.txt" ]; then
        EVAL_URL=$(cat EVALUATION_ENDPOINT.txt)
        echo "✅ Evaluation URL: $EVAL_URL"
    else
        echo "❌ EVALUATION_ENDPOINT.txt not found"
        echo "Run: ./deploy-evaluation-lambda.sh"
    fi
else
    echo "❌ Evaluation Lambda not found"
    echo "Run: ./deploy-evaluation-lambda.sh"
fi

echo ""
echo "3. Checking Submission Lambda..."
if aws lambda get-function --function-name k8s-submission-handler >/dev/null 2>&1; then
    echo "✅ Submission Lambda exists"

    if [ -f "SUBMISSION_ENDPOINT.txt" ]; then
        SUB_URL=$(cat SUBMISSION_ENDPOINT.txt)
        echo "✅ Submission URL: $SUB_URL"
    else
        echo "❌ SUBMISSION_ENDPOINT.txt not found"
        echo "Run: ./deploy-submission-lambda.sh"
    fi
else
    echo "❌ Submission Lambda not found"
    echo "Run: ./deploy-submission-lambda.sh"
fi

echo ""
echo "4. Testing Lambda connectivity..."
if [ -f "EVALUATION_ENDPOINT.txt" ]; then
    EVAL_URL=$(cat EVALUATION_ENDPOINT.txt)

    # Test with minimal payload
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d '{"student_id": "TEST", "task_id": "test"}' \
        "$EVAL_URL" || echo "CURL_FAILED")

    if [[ "$RESPONSE" == *"Missing required parameters"* ]] || [[ "$RESPONSE" == *"error"* ]]; then
        echo "✅ Evaluation Lambda responding correctly"
    else
        echo "❌ Evaluation Lambda not responding as expected"
        echo "Response: $RESPONSE"
    fi
fi

echo ""
echo "=== Setup Test Complete ==="

# Check if ready for quick deploy link creation
if [ -f "EVALUATION_ENDPOINT.txt" ] && [ -f "SUBMISSION_ENDPOINT.txt" ]; then
    echo ""
    echo "🎯 Ready for quick deploy link creation!"
    echo "Next step: cd ../cloudformation && ./create-quick-deploy-link.sh \\"
    echo "  \"\$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)\" \\"
    echo "  \"\$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)\" \\"
    echo "  \"your-keypair-name\""
else
    echo ""
    echo "⚠️  Not ready yet. Complete the missing steps above first."
fi