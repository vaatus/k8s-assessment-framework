#!/bin/bash
set -e

echo "=== Testing Student Workflow ==="

# Check prerequisites
echo "1. Checking prerequisites..."

if [ ! -f "../instructor-tools/EVALUATION_ENDPOINT.txt" ]; then
    echo "❌ EVALUATION_ENDPOINT.txt not found"
    echo "Run instructor setup first: cd ../instructor-tools && ./deploy-evaluation-lambda.sh"
    exit 1
fi

if [ ! -f "../instructor-tools/SUBMISSION_ENDPOINT.txt" ]; then
    echo "❌ SUBMISSION_ENDPOINT.txt not found"
    echo "Run instructor setup first: cd ../instructor-tools && ./deploy-submission-lambda.sh"
    exit 1
fi

if [ ! -f "cluster-endpoint.txt" ] || [ ! -f "cluster-token.txt" ]; then
    echo "❌ Cluster credentials not found"
    echo "Run manual k3s setup first: ./manual-k3s-setup.sh"
    exit 1
fi

# Copy endpoint files
echo "2. Setting up environment..."
cp ../instructor-tools/EVALUATION_ENDPOINT.txt ./
cp ../instructor-tools/SUBMISSION_ENDPOINT.txt ./

# Create student ID
echo "TEST123" > student-id.txt

echo "✅ Environment prepared"

# Test evaluation request
echo ""
echo "3. Testing evaluation request..."
cd ../student-tools

if ./request-evaluation.sh task-01; then
    echo "✅ Evaluation request successful"

    # Check if token was created
    if [ -f "eval-token-task-01.txt" ]; then
        echo "✅ Evaluation token created"

        # Test submission
        echo ""
        echo "4. Testing submission..."
        if ./submit-final.sh task-01 << 'EOF'
yes
EOF
        then
            echo "✅ Submission successful"
        else
            echo "❌ Submission failed"
        fi
    else
        echo "❌ No evaluation token created"
    fi
else
    echo "❌ Evaluation request failed"
fi

echo ""
echo "=== Workflow Test Complete ==="