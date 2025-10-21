#!/bin/bash
set -e

echo "=== Setting up Cross-Account Access for CloudFormation Templates ==="

BUCKET_NAME="k8s-assessment-templates"
REGION="us-east-1"

# Get current account ID (instructor account)
INSTRUCTOR_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

echo "Instructor Account ID: ${INSTRUCTOR_ACCOUNT}"
echo ""
echo "This script will configure the S3 bucket to allow cross-account access."
echo "Students will be able to access the CloudFormation template from their AWS accounts."
echo ""

# Create bucket policy that allows cross-account access
# This allows ANY authenticated AWS account to read the template
cat > /tmp/cross-account-bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCrossAccountReadForTemplates",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}/student-quick-deploy.yaml",
                "arn:aws:s3:::${BUCKET_NAME}/index.html"
            ],
            "Condition": {
                "StringLike": {
                    "aws:PrincipalArn": "arn:aws:iam::*:role/voclabs"
                }
            }
        },
        {
            "Sid": "AllowListBucket",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}",
            "Condition": {
                "StringLike": {
                    "aws:PrincipalArn": "arn:aws:iam::*:role/voclabs"
                }
            }
        }
    ]
}
EOF

echo "Applying cross-account bucket policy..."
if aws s3api put-bucket-policy --bucket ${BUCKET_NAME} --policy file:///tmp/cross-account-bucket-policy.json; then
    echo "✅ Cross-account bucket policy applied successfully!"
    echo ""
    echo "Students from other AWS Learner Lab accounts can now access:"
    echo "  - https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/student-quick-deploy.yaml"
    echo "  - https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/index.html"
    echo ""
    echo "The policy allows access from any AWS account with 'voclabs' role (AWS Learner Lab accounts)"
else
    echo "❌ Failed to apply cross-account bucket policy"
    echo ""
    echo "This may be due to account-level Block Public Access settings."
    echo "Alternative solution: Students can copy the template file manually."
fi

# Clean up
rm -f /tmp/cross-account-bucket-policy.json

echo ""
echo "=== Setup Complete ==="
