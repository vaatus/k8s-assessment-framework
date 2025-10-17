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
CLUSTER_ENDPOINT=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN=$(kubectl get secret -n kube-system $(kubectl get serviceaccount default -n kube-system -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || kubectl create token default -n kube-system --duration=3600s)

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