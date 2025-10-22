#!/bin/bash
set -e

echo "=== Enabling Public Access for CloudFormation Template Bucket ==="
echo ""
echo "This script attempts multiple methods to enable public access"
echo "to the CloudFormation template bucket, similar to the working"
echo "professor setup (vitmac12-resources)."
echo ""

BUCKET_NAME="k8s-assessment-templates"
REGION="us-east-1"

echo "Target Bucket: ${BUCKET_NAME}"
echo ""

# Method 1: Set bucket-level Block Public Access to false
echo "=== Method 1: Disable Bucket-Level Block Public Access ==="
if aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false" 2>/dev/null; then
    echo "✅ Bucket-level Block Public Access disabled"
else
    echo "⚠️  Could not disable bucket-level Block Public Access"
    echo "   This is controlled at the account level in Learner Lab"
fi

echo ""

# Method 2: Set individual object ACLs to public-read
echo "=== Method 2: Set Object ACLs to Public-Read ==="
echo "Setting student-quick-deploy.yaml to public-read..."
if aws s3api put-object-acl \
    --bucket ${BUCKET_NAME} \
    --key student-quick-deploy.yaml \
    --acl public-read 2>/dev/null; then
    echo "✅ Template file ACL set to public-read"
else
    echo "⚠️  Could not set object ACL (may be blocked by account policy)"
fi

echo "Setting index.html to public-read..."
if aws s3api put-object-acl \
    --bucket ${BUCKET_NAME} \
    --key index.html \
    --acl public-read 2>/dev/null; then
    echo "✅ HTML file ACL set to public-read"
else
    echo "⚠️  Could not set object ACL (may be blocked by account policy)"
fi

echo ""

# Method 3: Upload with public-read ACL
echo "=== Method 3: Re-upload Files with Public-Read ACL ==="
echo "Re-uploading template with public-read ACL..."

if [ -f "student-quick-deploy.yaml.tmp" ]; then
    if aws s3 cp student-quick-deploy.yaml.tmp \
        "s3://${BUCKET_NAME}/student-quick-deploy.yaml" \
        --acl public-read \
        --region ${REGION} 2>/dev/null; then
        echo "✅ Template uploaded with public-read ACL"
    else
        echo "⚠️  Could not upload with public-read ACL"
    fi
fi

echo ""

# Method 4: Try simple bucket policy (what likely works for vitmac12-resources)
echo "=== Method 4: Apply Simple Public Read Bucket Policy ==="
cat > /tmp/simple-public-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF

if aws s3api put-bucket-policy \
    --bucket ${BUCKET_NAME} \
    --policy file:///tmp/simple-public-policy.json 2>/dev/null; then
    echo "✅ Simple public bucket policy applied successfully!"
else
    echo "⚠️  Could not apply public bucket policy"
fi

rm -f /tmp/simple-public-policy.json

echo ""

# Method 5: Check current bucket configuration
echo "=== Verifying Current Configuration ==="

echo "Bucket Public Access Block settings:"
aws s3api get-public-access-block --bucket ${BUCKET_NAME} 2>/dev/null || echo "  No bucket-level settings (inheriting from account)"

echo ""
echo "Bucket Policy:"
aws s3api get-bucket-policy --bucket ${BUCKET_NAME} --query Policy --output text 2>/dev/null | jq '.' 2>/dev/null || echo "  No bucket policy set"

echo ""

# Test access
echo "=== Testing Public Access ==="
TEMPLATE_URL="https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/student-quick-deploy.yaml"
echo "Template URL: ${TEMPLATE_URL}"
echo ""
echo "Testing access (this may fail if still private)..."

if curl -s -f -I "${TEMPLATE_URL}" > /dev/null 2>&1; then
    echo "✅ SUCCESS! Template is publicly accessible!"
    echo ""
    echo "You can now share this URL with students:"
    echo "  ${TEMPLATE_URL}"
    echo ""
    echo "CloudFormation Quick Deploy Link:"
    QUICK_DEPLOY_URL="https://${REGION}.console.aws.amazon.com/cloudformation/home?region=${REGION}#/stacks/create/review?templateURL=${TEMPLATE_URL}&stackName=k8s-student-environment"
    echo "  ${QUICK_DEPLOY_URL}"
else
    echo "❌ Template is NOT publicly accessible yet"
    echo ""
    echo "Possible reasons:"
    echo "  1. Account-level Block Public Access is enforced"
    echo "  2. Bucket policy is being blocked"
    echo "  3. Object ACLs are being blocked"
    echo ""
    echo "Alternative: Contact AWS Academy support to request S3 public access"
    echo "Or use manual template distribution method"
fi

echo ""
echo "=== Configuration Attempt Complete ==="
