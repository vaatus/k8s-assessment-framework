#!/bin/bash
set -e

echo "=== Setting up S3 Buckets for K8s Assessment Framework ==="

RESULTS_BUCKET="k8s-eval-results"
TEMPLATES_BUCKET="k8s-assessment-templates"
REGION="us-east-1"

echo ""
echo "=== 1. Creating Private Results Bucket ==="

# Check if results bucket exists
if aws s3 ls "s3://${RESULTS_BUCKET}" 2>/dev/null; then
    echo "✅ Bucket ${RESULTS_BUCKET} already exists"
else
    echo "Creating S3 bucket: ${RESULTS_BUCKET}"
    aws s3 mb "s3://${RESULTS_BUCKET}" --region ${REGION}
    echo "✅ Bucket ${RESULTS_BUCKET} created"
fi

# Set bucket policy for evaluation access (private)
echo "Setting private bucket policy..."
cat > /tmp/results-bucket-policy.json << EOF
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
            "Resource": "arn:aws:s3:::${RESULTS_BUCKET}/*"
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
            "Resource": "arn:aws:s3:::${RESULTS_BUCKET}"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket ${RESULTS_BUCKET} --policy file:///tmp/results-bucket-policy.json

# Create folder structure
echo "Creating folder structure..."
echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/evaluations/.placeholder"
echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/submissions/.placeholder"
echo "" | aws s3 cp - "s3://${RESULTS_BUCKET}/tasks/.placeholder"
echo "✅ Results bucket configured"

echo ""
echo "=== 2. Creating Public Templates Bucket ==="

# Check if templates bucket exists
if aws s3 ls "s3://${TEMPLATES_BUCKET}" 2>/dev/null; then
    echo "✅ Bucket ${TEMPLATES_BUCKET} already exists"
else
    echo "Creating S3 bucket: ${TEMPLATES_BUCKET}"
    aws s3 mb "s3://${TEMPLATES_BUCKET}" --region ${REGION}
    echo "✅ Bucket ${TEMPLATES_BUCKET} created"
fi

# Try to set public bucket policy for templates
echo "Setting public bucket policy for templates..."
cat > /tmp/templates-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadAccess",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${TEMPLATES_BUCKET}/*"
        }
    ]
}
EOF

# Try to set the public policy (may fail in Learner Lab)
if aws s3api put-bucket-policy --bucket ${TEMPLATES_BUCKET} --policy file:///tmp/templates-bucket-policy.json 2>/dev/null; then
    echo "✅ Public bucket policy set successfully"
else
    echo "⚠️  WARNING: Could not set public bucket policy (AWS Learner Lab restriction)"
    echo "   Templates bucket created but not public. You can:"
    echo "   1. Manually share the template file with students, OR"
    echo "   2. Use CloudFormation console to upload template directly"
fi

echo "✅ Templates bucket configured"

# Clean up temp files
rm -f /tmp/results-bucket-policy.json /tmp/templates-bucket-policy.json

echo ""
echo "==================================="
echo "✅ S3 Buckets Setup Complete!"
echo "==================================="
echo "Results Bucket (Private): ${RESULTS_BUCKET}"
echo "Templates Bucket (Public): ${TEMPLATES_BUCKET}"
echo "Region: ${REGION}"
echo ""
echo "Next Steps:"
echo "1. Run: cd ../cloudformation && ./create-quick-deploy-link.sh <eval-endpoint> <submit-endpoint> <api-key>"
echo "2. This will upload the CloudFormation template to the templates bucket"
echo "==================================="