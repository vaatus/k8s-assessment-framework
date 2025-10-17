#!/bin/bash
set -e

echo "=== Setting up S3 Bucket for K8s Evaluation Results ==="

BUCKET_NAME="k8s-eval-results"
REGION="us-east-1"

# Check if bucket exists
if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "Bucket ${BUCKET_NAME} already exists"
else
    echo "Creating S3 bucket: ${BUCKET_NAME}"
    aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION}
fi

# Set bucket policy for evaluation access
echo "Setting bucket policy..."
cat > /tmp/bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EvaluationAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole"
            },
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        },
        {
            "Sid": "BucketAccess",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/LabRole"
            },
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::${BUCKET_NAME}"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket ${BUCKET_NAME} --policy file:///tmp/bucket-policy.json

# Create folder structure
echo "Creating folder structure..."
echo "" | aws s3 cp - "s3://${BUCKET_NAME}/evaluations/.placeholder"
echo "" | aws s3 cp - "s3://${BUCKET_NAME}/submissions/.placeholder"
echo "" | aws s3 cp - "s3://${BUCKET_NAME}/tasks/.placeholder"

echo ""
echo "==================================="
echo "S3 Bucket Setup Complete!"
echo "Bucket Name: ${BUCKET_NAME}"
echo "Region: ${REGION}"
echo "==================================="