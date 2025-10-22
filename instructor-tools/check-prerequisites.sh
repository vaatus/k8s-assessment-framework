#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          Pre-Deployment Prerequisites Check                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0

# Check 1: AWS CLI
echo -n "Checking AWS CLI... "
if command -v aws &> /dev/null; then
    echo -e "${GREEN}✅ Installed${NC}"
    aws --version
    ((CHECKS_PASSED++))
else
    echo -e "${RED}❌ Not found${NC}"
    ((CHECKS_FAILED++))
fi

echo ""

# Check 2: AWS Credentials
echo -n "Checking AWS credentials... "
if timeout 10 aws sts get-caller-identity &> /dev/null; then
    echo -e "${GREEN}✅ Valid${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    echo "   Account ID: $ACCOUNT_ID"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}❌ Invalid or timed out${NC}"
    echo "   Please run: aws configure"
    ((CHECKS_FAILED++))
fi

echo ""

# Check 3: Region
echo -n "Checking AWS region... "
REGION=$(aws configure get region 2>/dev/null || echo "not set")
if [ "$REGION" = "us-east-1" ] || [ "$REGION" = "not set" ]; then
    echo -e "${GREEN}✅ OK${NC} (using us-east-1)"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Warning${NC}: Current region is $REGION"
    echo "   This framework uses us-east-1 by default"
    ((CHECKS_PASSED++))
fi

echo ""

# Check 4: jq (optional)
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✅ Installed${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Not found${NC} (optional, but helpful for viewing JSON results)"
    ((CHECKS_PASSED++))
fi

echo ""

# Check 5: Required permissions
echo -n "Checking IAM permissions... "
# Try to list S3 buckets as a basic permission check
if timeout 10 aws s3 ls &> /dev/null; then
    echo -e "${GREEN}✅ Basic permissions OK${NC}"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}❌ Insufficient permissions${NC}"
    echo "   Ensure you have permissions for S3, Lambda, CloudFormation, IAM"
    ((CHECKS_FAILED++))
fi

echo ""

# Check 6: LabRole (for AWS Learner Lab)
echo -n "Checking LabRole... "
if timeout 10 aws iam get-role --role-name LabRole &> /dev/null; then
    echo -e "${GREEN}✅ Found${NC} (AWS Learner Lab detected)"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Not found${NC} (OK if not using AWS Learner Lab)"
    echo "   If using AWS Learner Lab, start your lab session first"
    ((CHECKS_PASSED++))
fi

echo ""

# Summary
echo "════════════════════════════════════════════════════════════════"
echo "Checks Passed: $CHECKS_PASSED"
echo "Checks Failed: $CHECKS_FAILED"
echo "════════════════════════════════════════════════════════════════"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All prerequisite checks passed!${NC}"
    echo ""
    echo "You are ready to deploy the framework."
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./deploy-complete-setup.sh"
    echo "  2. After deployment, run: ./test-complete-deployment.sh"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some prerequisite checks failed${NC}"
    echo ""
    echo "Please fix the issues above before deploying."
    echo ""
    exit 1
fi
