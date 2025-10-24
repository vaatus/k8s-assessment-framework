#!/bin/bash
set -e

echo "=========================================="
echo " Upload Task Specifications to S3"
echo "=========================================="
echo ""

BUCKET_NAME="k8s-eval-results"
REGION="us-east-1"

# Check if we're in the correct directory
if [ ! -f "upload-task-specs.sh" ]; then
    echo "Error: Please run this script from the instructor-tools directory"
    exit 1
fi

# Check if bucket exists
if ! aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "Error: Bucket ${BUCKET_NAME} does not exist"
    echo "Run deploy-complete-setup.sh first"
    exit 1
fi

echo "Uploading task specifications to s3://${BUCKET_NAME}/task-specs/"
echo ""

# Upload all task specs
cd ../tasks

TASK_COUNT=0
for task_dir in task-*/; do
    if [ -f "${task_dir}task-spec.yaml" ]; then
        task_id=$(basename "$task_dir")
        echo "Uploading ${task_id}/task-spec.yaml..."

        aws s3 cp "${task_dir}task-spec.yaml" \
            "s3://${BUCKET_NAME}/task-specs/${task_id}/task-spec.yaml" \
            --region ${REGION}

        TASK_COUNT=$((TASK_COUNT + 1))
    fi
done

cd ../instructor-tools

echo ""
echo "✅ Uploaded ${TASK_COUNT} task specifications"
echo ""
echo "Task specs available at:"
echo "  s3://${BUCKET_NAME}/task-specs/task-01/task-spec.yaml"
echo "  s3://${BUCKET_NAME}/task-specs/task-02/task-spec.yaml"
echo "  s3://${BUCKET_NAME}/task-specs/task-03/task-spec.yaml"
echo ""
echo "The dynamic evaluator will automatically load these specs."
