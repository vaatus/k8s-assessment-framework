#!/bin/bash
set -e

echo "=== Kubernetes Task Evaluation Request ==="

# Configuration - These will be provided by instructor
EVALUATION_ENDPOINT_FILE="../EVALUATION_ENDPOINT.txt"
STUDENT_ID_FILE="../student-id.txt"

# Check for required files
if [ ! -f "$EVALUATION_ENDPOINT_FILE" ]; then
    echo "ERROR: EVALUATION_ENDPOINT.txt not found"
    echo "Please ensure the instructor has provided the evaluation endpoint"
    exit 1
fi

if [ ! -f "$STUDENT_ID_FILE" ]; then
    echo "ERROR: student-id.txt not found"
    echo "Please create student-id.txt with your student ID"
    exit 1
fi

EVALUATION_ENDPOINT=$(cat $EVALUATION_ENDPOINT_FILE)
STUDENT_ID=$(cat $STUDENT_ID_FILE | tr -d '\n\r ')

# Task configuration
TASK_ID=${1:-"task-01"}
NAMESPACE="task-${TASK_ID}"

if [ -z "$1" ]; then
    echo "Usage: $0 <task-id>"
    echo "Example: $0 task-01"
    exit 1
fi

echo "Student ID: ${STUDENT_ID}"
echo "Task ID: ${TASK_ID}"
echo "Namespace: ${NAMESPACE}"

# Get cluster endpoint and token
echo "Getting cluster information..."

# Check if cluster credentials are already saved
if [ -f "../cluster-endpoint.txt" ] && [ -f "../cluster-token.txt" ]; then
    echo "Using saved cluster credentials..."
    CLUSTER_ENDPOINT=$(cat ../cluster-endpoint.txt | tr -d '\n\r ')
    CLUSTER_TOKEN=$(cat ../cluster-token.txt | tr -d '\n\r ')
elif [ -f "cluster-endpoint.txt" ] && [ -f "cluster-token.txt" ]; then
    echo "Using saved cluster credentials from current directory..."
    CLUSTER_ENDPOINT=$(cat cluster-endpoint.txt | tr -d '\n\r ')
    CLUSTER_TOKEN=$(cat cluster-token.txt | tr -d '\n\r ')
else
    echo "Getting cluster credentials from kubectl..."
    CLUSTER_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

    # If cluster endpoint is localhost, update it to external IP
    if [[ "$CLUSTER_ENDPOINT" == *"127.0.0.1"* ]] || [[ "$CLUSTER_ENDPOINT" == *"localhost"* ]]; then
        echo "Detected localhost endpoint, updating to external IP..."
        EXTERNAL_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")
        if [ -n "$EXTERNAL_IP" ]; then
            CLUSTER_ENDPOINT="https://${EXTERNAL_IP}:6443"
            echo "Updated cluster endpoint to: ${CLUSTER_ENDPOINT}"
        else
            echo "WARNING: Could not get external IP, using localhost endpoint"
        fi
    fi

    # Try to get token from evaluator service account first
    CLUSTER_TOKEN=$(kubectl get secret evaluator-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

    # Fallback to creating a temporary token
    if [ -z "$CLUSTER_TOKEN" ]; then
        echo "Creating temporary evaluation token..."
        CLUSTER_TOKEN=$(kubectl create token evaluator -n kube-system --duration=3600s 2>/dev/null || kubectl create token default -n kube-system --duration=3600s)
    fi
fi

if [ -z "$CLUSTER_ENDPOINT" ] || [ -z "$CLUSTER_TOKEN" ]; then
    echo "ERROR: Could not retrieve cluster credentials"
    echo "Make sure you're connected to your Kubernetes cluster"
    exit 1
fi

echo "Cluster Endpoint: ${CLUSTER_ENDPOINT}"

# Create evaluation request payload
REQUEST_PAYLOAD=$(cat << EOF
{
    "student_id": "${STUDENT_ID}",
    "task_id": "${TASK_ID}",
    "cluster_endpoint": "${CLUSTER_ENDPOINT}",
    "cluster_token": "${CLUSTER_TOKEN}"
}
EOF
)

echo ""
echo "Requesting evaluation..."

# Make evaluation request
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "$REQUEST_PAYLOAD" \
    "$EVALUATION_ENDPOINT")

echo ""
echo "=== EVALUATION RESULTS ==="
echo "$RESPONSE" | jq '.'

# Extract and save evaluation token
EVAL_TOKEN=$(echo "$RESPONSE" | jq -r '.eval_token // empty')
if [ -n "$EVAL_TOKEN" ] && [ "$EVAL_TOKEN" != "null" ]; then
    echo "$EVAL_TOKEN" > "eval-token-${TASK_ID}.txt"
    echo ""
    echo "Evaluation token saved to: eval-token-${TASK_ID}.txt"
    echo "Use this token to submit your final results when satisfied"
fi

echo ""
echo "=== EVALUATION COMPLETE ==="