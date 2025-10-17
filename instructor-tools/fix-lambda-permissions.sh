#!/bin/bash
set -e

echo "=== Fixing Lambda Permissions ==="

REGION="us-east-1"
BUCKET_NAME="k8s-eval-results"

# Get LabRole ARN
ROLE_ARN=$(aws iam get-role --role-name LabRole --query 'Role.Arn' --output text)
echo "Using Role ARN: ${ROLE_ARN}"

# Update Lambda environment variables and configuration
echo "Updating evaluation Lambda configuration..."
aws lambda update-function-configuration \
    --function-name k8s-task-evaluator \
    --environment Variables="{BUCKET_NAME=${BUCKET_NAME}}" \
    --region ${REGION}

echo "Updating submission Lambda configuration..."
aws lambda update-function-configuration \
    --function-name k8s-submission-handler \
    --environment Variables="{BUCKET_NAME=${BUCKET_NAME}}" \
    --region ${REGION}

# Add resource-based policy to allow public invocation via Function URL
echo "Adding resource-based policy for evaluation Lambda..."
aws lambda add-permission \
    --function-name k8s-task-evaluator \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null || echo "Permission already exists"

echo "Adding resource-based policy for submission Lambda..."
aws lambda add-permission \
    --function-name k8s-submission-handler \
    --statement-id FunctionURLAllowPublicAccess \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE \
    --region ${REGION} 2>/dev/null || echo "Permission already exists"

# Verify the Lambda can access S3
echo "Testing S3 access from Lambda execution role..."
POLICY_DOC=$(cat << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::k8s-eval-results",
                "arn:aws:s3:::k8s-eval-results/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
)

# Create and attach S3 policy (if it doesn't exist)
POLICY_NAME="LambdaS3AccessPolicy"
echo "Creating/updating IAM policy for S3 access..."

# Try to create policy, ignore if it already exists
aws iam create-policy \
    --policy-name ${POLICY_NAME} \
    --policy-document "$POLICY_DOC" \
    --description "Policy for Lambda to access k8s-eval-results S3 bucket" 2>/dev/null || echo "Policy already exists"

# Get account ID and attach policy to LabRole
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

aws iam attach-role-policy \
    --role-name LabRole \
    --policy-arn ${POLICY_ARN} 2>/dev/null || echo "Policy already attached"

echo ""
echo "=== Permissions Fixed ==="
echo "Waiting 10 seconds for changes to propagate..."
sleep 10

echo "Testing Lambda connectivity again..."
EVAL_URL=$(cat EVALUATION_ENDPOINT.txt)

# Test with invalid data to check if Lambda responds
RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"test": "connectivity"}' \
    "$EVAL_URL")

echo "Response: $RESPONSE"

if [[ "$RESPONSE" == *"error"* ]] || [[ "$RESPONSE" == *"Missing required parameters"* ]]; then
    echo "✅ Lambda is now responding correctly!"
else
    echo "❌ Lambda still not responding as expected"
    echo "Check CloudWatch logs for more details:"
    echo "aws logs tail /aws/lambda/k8s-task-evaluator --follow"
fi