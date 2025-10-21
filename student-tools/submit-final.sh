#!/bin/bash
set -e

echo "=== Final Task Submission ==="

# Configuration files
SUBMISSION_ENDPOINT_FILE="../SUBMISSION_ENDPOINT.txt"
STUDENT_ID_FILE="../student-id.txt"
API_KEY_FILE="../API_KEY.txt"

# Check for required files
if [ ! -f "$SUBMISSION_ENDPOINT_FILE" ]; then
    echo "ERROR: SUBMISSION_ENDPOINT.txt not found"
    echo "Please ensure the instructor has provided the submission endpoint"
    exit 1
fi

if [ ! -f "$STUDENT_ID_FILE" ]; then
    echo "ERROR: student-id.txt not found"
    echo "Please create student-id.txt with your student ID"
    exit 1
fi

if [ ! -f "$API_KEY_FILE" ]; then
    echo "ERROR: API_KEY.txt not found"
    echo "Please ensure the instructor has provided the API key"
    exit 1
fi

SUBMISSION_ENDPOINT=$(cat $SUBMISSION_ENDPOINT_FILE)
STUDENT_ID=$(cat $STUDENT_ID_FILE | tr -d '\n\r ')
API_KEY=$(cat $API_KEY_FILE | tr -d '\n\r ')

# Task configuration
TASK_ID=${1:-"task-01"}
EVAL_TOKEN_FILE="eval-token-${TASK_ID}.txt"

if [ -z "$1" ]; then
    echo "Usage: $0 <task-id>"
    echo "Example: $0 task-01"
    exit 1
fi

if [ ! -f "$EVAL_TOKEN_FILE" ]; then
    echo "ERROR: ${EVAL_TOKEN_FILE} not found"
    echo "Please run request-evaluation.sh first to get an evaluation token"
    exit 1
fi

EVAL_TOKEN=$(cat $EVAL_TOKEN_FILE | tr -d '\n\r ')

echo "Student ID: ${STUDENT_ID}"
echo "Task ID: ${TASK_ID}"
echo "Evaluation Token: ${EVAL_TOKEN}"

# Confirm submission
echo ""
echo "WARNING: This will submit your final results for grading."
echo "Make sure you have:"
echo "1. Completed the task requirements"
echo "2. Run request-evaluation.sh and reviewed the results"
echo "3. Made any necessary corrections"
echo ""
read -p "Are you sure you want to submit? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Submission cancelled"
    exit 0
fi

# Create submission payload
SUBMISSION_PAYLOAD=$(cat << EOF
{
    "student_id": "${STUDENT_ID}",
    "task_id": "${TASK_ID}",
    "eval_token": "${EVAL_TOKEN}"
}
EOF
)

echo ""
echo "Submitting final results..."

# Make submission request
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "X-API-Key: ${API_KEY}" \
    -d "$SUBMISSION_PAYLOAD" \
    "$SUBMISSION_ENDPOINT")

echo ""
echo "=== SUBMISSION RESULTS ==="
echo "$RESPONSE" | jq '.'

# Check if submission was successful
STATUS=$(echo "$RESPONSE" | jq -r '.message // .error')
if echo "$RESPONSE" | jq -e '.message' > /dev/null; then
    echo ""
    echo "✅ SUBMISSION SUCCESSFUL!"

    # Clean up token file after successful submission
    rm -f "$EVAL_TOKEN_FILE"
    echo "Evaluation token cleaned up"
else
    echo ""
    echo "❌ SUBMISSION FAILED!"
fi

echo ""
echo "=== SUBMISSION COMPLETE ==="