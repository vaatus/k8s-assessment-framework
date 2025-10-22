#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Kubernetes Assessment Framework - Complete Test Suite    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

REGION="us-east-1"
RESULTS_BUCKET="k8s-eval-results"
TEMPLATES_BUCKET="k8s-assessment-templates"
TEST_NEPTUN="TEST01"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0

function print_test() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "TEST: $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function pass_test() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

function fail_test() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

function warn_test() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

# ============================================================================
# Test 1: Check Prerequisites
# ============================================================================
print_test "Prerequisites Check"

# Check AWS CLI
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    pass_test "AWS CLI installed: $AWS_VERSION"
else
    fail_test "AWS CLI not found"
    exit 1
fi

# Check jq
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version 2>&1)
    pass_test "jq installed: $JQ_VERSION"
else
    warn_test "jq not found (optional, but recommended)"
fi

# Check AWS credentials
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    pass_test "AWS credentials valid"
    echo "   Account ID: $ACCOUNT_ID"
    echo "   User ARN: $USER_ARN"
else
    fail_test "AWS credentials not configured"
    exit 1
fi

# Check region
CURRENT_REGION=$(aws configure get region || echo "us-east-1")
if [ "$CURRENT_REGION" != "$REGION" ]; then
    warn_test "Current region is $CURRENT_REGION, expected $REGION"
fi

# ============================================================================
# Test 2: Check S3 Buckets
# ============================================================================
print_test "S3 Buckets"

# Check results bucket
if aws s3 ls "s3://${RESULTS_BUCKET}" 2>/dev/null; then
    pass_test "Results bucket exists: ${RESULTS_BUCKET}"

    # Check folder structure
    if aws s3 ls "s3://${RESULTS_BUCKET}/evaluations/" 2>/dev/null; then
        pass_test "Evaluations folder exists"
    else
        warn_test "Evaluations folder missing"
    fi

    if aws s3 ls "s3://${RESULTS_BUCKET}/submissions/" 2>/dev/null; then
        pass_test "Submissions folder exists"
    else
        warn_test "Submissions folder missing"
    fi
else
    fail_test "Results bucket not found: ${RESULTS_BUCKET}"
fi

# Check templates bucket
if aws s3 ls "s3://${TEMPLATES_BUCKET}" 2>/dev/null; then
    pass_test "Templates bucket exists: ${TEMPLATES_BUCKET}"

    # Check public access
    if aws s3api get-public-access-block --bucket ${TEMPLATES_BUCKET} 2>/dev/null | grep -q "false"; then
        pass_test "Templates bucket public access configured"
    else
        warn_test "Templates bucket may not be publicly accessible"
    fi

    # Check bucket policy
    if aws s3api get-bucket-policy --bucket ${TEMPLATES_BUCKET} 2>/dev/null; then
        pass_test "Templates bucket policy exists"
    else
        warn_test "Templates bucket policy not found"
    fi
else
    fail_test "Templates bucket not found: ${TEMPLATES_BUCKET}"
fi

# ============================================================================
# Test 3: Check Lambda Functions
# ============================================================================
print_test "Lambda Functions"

# Check evaluation Lambda
EVAL_FUNCTION="k8s-evaluation-function"
if aws lambda get-function --function-name ${EVAL_FUNCTION} 2>/dev/null; then
    pass_test "Evaluation Lambda exists: ${EVAL_FUNCTION}"

    # Check runtime
    RUNTIME=$(aws lambda get-function-configuration --function-name ${EVAL_FUNCTION} --query Runtime --output text)
    if [[ "$RUNTIME" == python3.* ]]; then
        pass_test "Evaluation Lambda runtime: $RUNTIME"
    else
        warn_test "Unexpected runtime: $RUNTIME"
    fi

    # Check environment variables
    if aws lambda get-function-configuration --function-name ${EVAL_FUNCTION} --query 'Environment.Variables.API_KEY' --output text 2>/dev/null | grep -q "."; then
        pass_test "Evaluation Lambda API_KEY configured"
    else
        warn_test "Evaluation Lambda API_KEY not set"
    fi

    # Check function URL
    EVAL_URL=$(aws lambda get-function-url-config --function-name ${EVAL_FUNCTION} --query 'FunctionUrl' --output text 2>/dev/null || echo "")
    if [ -n "$EVAL_URL" ]; then
        pass_test "Evaluation Lambda URL exists: ${EVAL_URL}"
    else
        fail_test "Evaluation Lambda URL not configured"
    fi
else
    fail_test "Evaluation Lambda not found: ${EVAL_FUNCTION}"
fi

# Check submission Lambda
SUBMIT_FUNCTION="k8s-submission-function"
if aws lambda get-function --function-name ${SUBMIT_FUNCTION} 2>/dev/null; then
    pass_test "Submission Lambda exists: ${SUBMIT_FUNCTION}"

    # Check runtime
    RUNTIME=$(aws lambda get-function-configuration --function-name ${SUBMIT_FUNCTION} --query Runtime --output text)
    if [[ "$RUNTIME" == python3.* ]]; then
        pass_test "Submission Lambda runtime: $RUNTIME"
    else
        warn_test "Unexpected runtime: $RUNTIME"
    fi

    # Check function URL
    SUBMIT_URL=$(aws lambda get-function-url-config --function-name ${SUBMIT_FUNCTION} --query 'FunctionUrl' --output text 2>/dev/null || echo "")
    if [ -n "$SUBMIT_URL" ]; then
        pass_test "Submission Lambda URL exists: ${SUBMIT_URL}"
    else
        fail_test "Submission Lambda URL not configured"
    fi
else
    fail_test "Submission Lambda not found: ${SUBMIT_FUNCTION}"
fi

# ============================================================================
# Test 4: Check Endpoint Files
# ============================================================================
print_test "Endpoint Configuration Files"

if [ -f "EVALUATION_ENDPOINT.txt" ]; then
    EVAL_ENDPOINT=$(cat EVALUATION_ENDPOINT.txt)
    pass_test "EVALUATION_ENDPOINT.txt exists"
    echo "   URL: $EVAL_ENDPOINT"
else
    fail_test "EVALUATION_ENDPOINT.txt not found"
fi

if [ -f "SUBMISSION_ENDPOINT.txt" ]; then
    SUBMIT_ENDPOINT=$(cat SUBMISSION_ENDPOINT.txt)
    pass_test "SUBMISSION_ENDPOINT.txt exists"
    echo "   URL: $SUBMIT_ENDPOINT"
else
    fail_test "SUBMISSION_ENDPOINT.txt not found"
fi

if [ -f "API_KEY.txt" ]; then
    API_KEY=$(cat API_KEY.txt)
    pass_test "API_KEY.txt exists"
    echo "   Key: ${API_KEY:0:8}... (hidden)"

    # Check permissions
    PERMS=$(stat -c %a API_KEY.txt 2>/dev/null || stat -f %A API_KEY.txt 2>/dev/null || echo "unknown")
    if [ "$PERMS" == "600" ]; then
        pass_test "API_KEY.txt has correct permissions (600)"
    else
        warn_test "API_KEY.txt permissions: $PERMS (should be 600)"
    fi
else
    fail_test "API_KEY.txt not found"
fi

# ============================================================================
# Test 5: Check CloudFormation Template
# ============================================================================
print_test "CloudFormation Template"

TEMPLATE_FILE="../cloudformation/unified-student-template.yaml"
if [ -f "$TEMPLATE_FILE" ]; then
    pass_test "Template file exists: $TEMPLATE_FILE"

    # Validate template
    if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" 2>/dev/null; then
        pass_test "Template is valid"
    else
        fail_test "Template validation failed"
    fi

    # Check if uploaded to S3
    if aws s3 ls "s3://${TEMPLATES_BUCKET}/unified-student-template.yaml" 2>/dev/null; then
        pass_test "Template uploaded to S3"

        # Check if publicly accessible
        TEMPLATE_URL="https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/unified-student-template.yaml"
        if curl -s -f -I "$TEMPLATE_URL" > /dev/null 2>&1; then
            pass_test "Template is publicly accessible"
            echo "   URL: $TEMPLATE_URL"
        else
            fail_test "Template not publicly accessible"
        fi
    else
        warn_test "Template not uploaded to S3"
    fi
else
    fail_test "Template file not found: $TEMPLATE_FILE"
fi

# Check landing page
if aws s3 ls "s3://${TEMPLATES_BUCKET}/index.html" 2>/dev/null; then
    pass_test "Student landing page uploaded"

    LANDING_URL="https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/index.html"
    if curl -s -f -I "$LANDING_URL" > /dev/null 2>&1; then
        pass_test "Landing page is publicly accessible"
        echo "   URL: $LANDING_URL"
    else
        warn_test "Landing page not publicly accessible"
    fi
else
    warn_test "Student landing page not found"
fi

# ============================================================================
# Test 6: Test Lambda Endpoints
# ============================================================================
print_test "Lambda Endpoint Connectivity"

if [ -f "EVALUATION_ENDPOINT.txt" ] && [ -f "API_KEY.txt" ]; then
    EVAL_ENDPOINT=$(cat EVALUATION_ENDPOINT.txt)
    API_KEY=$(cat API_KEY.txt)

    # Test evaluation endpoint with test payload
    echo "Testing evaluation endpoint..."
    EVAL_RESPONSE=$(curl -s -X POST "$EVAL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $API_KEY" \
        -d '{"test": true, "neptun_code": "TEST01", "task_id": "test"}' 2>&1)

    if echo "$EVAL_RESPONSE" | grep -q "error\|statusCode"; then
        # Check if it's an expected error (like missing cluster credentials)
        if echo "$EVAL_RESPONSE" | grep -q "kube_api_url"; then
            pass_test "Evaluation endpoint reachable (validation working)"
        else
            warn_test "Evaluation endpoint returned error: $EVAL_RESPONSE"
        fi
    else
        pass_test "Evaluation endpoint responding"
    fi

    # Test without API key (should fail)
    echo "Testing evaluation endpoint without API key (should fail)..."
    UNAUTH_RESPONSE=$(curl -s -X POST "$EVAL_ENDPOINT" \
        -H "Content-Type: application/json" \
        -d '{"test": true}' 2>&1)

    if echo "$UNAUTH_RESPONSE" | grep -q "Unauthorized\|401"; then
        pass_test "API key authentication working"
    else
        fail_test "API key authentication not enforced"
    fi
fi

if [ -f "SUBMISSION_ENDPOINT.txt" ] && [ -f "API_KEY.txt" ]; then
    SUBMIT_ENDPOINT=$(cat SUBMISSION_ENDPOINT.txt)
    API_KEY=$(cat API_KEY.txt)

    # Test submission endpoint
    echo "Testing submission endpoint..."
    SUBMIT_RESPONSE=$(curl -s -X POST "$SUBMIT_ENDPOINT" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $API_KEY" \
        -d '{"test": true}' 2>&1)

    if echo "$SUBMIT_RESPONSE" | grep -q "error\|Missing\|400"; then
        pass_test "Submission endpoint reachable (validation working)"
    else
        warn_test "Submission endpoint response: $SUBMIT_RESPONSE"
    fi
fi

# ============================================================================
# Test 7: Check IAM Role
# ============================================================================
print_test "IAM Configuration"

if aws iam get-role --role-name LabRole 2>/dev/null; then
    pass_test "LabRole exists (required for AWS Learner Lab)"
else
    warn_test "LabRole not found (required for AWS Learner Lab)"
fi

# ============================================================================
# Test Summary
# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      Test Summary                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
PASS_RATE=$(( TESTS_PASSED * 100 / TOTAL_TESTS ))

echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo "Pass Rate: ${PASS_RATE}%"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✅ ALL TESTS PASSED!                             ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your Kubernetes Assessment Framework is ready for deployment!"
    echo ""
    echo "📋 Next Steps:"
    echo "   1. Share the landing page URL with students:"
    echo "      https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/index.html"
    echo ""
    echo "   2. Test student deployment:"
    echo "      - Open the landing page URL"
    echo "      - Click 'Deploy My Environment'"
    echo "      - Use Neptun Code: TEST01"
    echo "      - Select task-01"
    echo ""
    echo "   3. Monitor results:"
    echo "      ./view-results.sh"
    echo ""
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ❌ SOME TESTS FAILED                             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "⚠️  Please review the failed tests above and:"
    echo "   1. Fix any issues"
    echo "   2. Run ./deploy-complete-setup.sh again if needed"
    echo "   3. Re-run this test script to verify fixes"
    echo ""
    exit 1
fi
