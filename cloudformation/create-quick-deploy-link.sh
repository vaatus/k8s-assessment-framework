#!/bin/bash
set -e

echo "=== Creating CloudFormation Quick Deploy Link ==="

# Configuration
BUCKET_NAME="k8s-assessment-templates"
TEMPLATE_FILE="student-quick-deploy.yaml"
REGION="us-east-1"
STACK_NAME_DEFAULT="k8s-student-environment"

# Parameters to update in template (from your instructor setup)
EVALUATION_ENDPOINT="${1}"
SUBMISSION_ENDPOINT="${2}"
API_KEY="${3}"
KEYPAIR_NAME="${4:-k8s-assessment-keypair}"

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Usage: $0 <evaluation-endpoint> <submission-endpoint> <api-key> [keypair-name]"
    echo ""
    echo "Example:"
    echo "$0 \\"
    echo "  'https://abc123.lambda-url.us-east-1.on.aws/' \\"
    echo "  'https://def456.lambda-url.us-east-1.on.aws/' \\"
    echo "  'your-api-key-here' \\"
    echo "  'my-keypair'"
    echo ""
    echo "Or use the endpoint files:"
    echo "$0 \\"
    echo "  \"\$(cat ../instructor-tools/EVALUATION_ENDPOINT.txt)\" \\"
    echo "  \"\$(cat ../instructor-tools/SUBMISSION_ENDPOINT.txt)\" \\"
    echo "  \"\$(cat ../instructor-tools/API_KEY.txt)\" \\"
    echo "  'my-keypair'"
    echo ""
    echo "This will create a quick deploy link that students can use."
    exit 1
fi

echo "Configuration:"
echo "  Evaluation Endpoint: ${EVALUATION_ENDPOINT}"
echo "  Submission Endpoint: ${SUBMISSION_ENDPOINT}"
echo "  API Key: ${API_KEY:0:8}... (hidden)"
echo "  Default Key Pair: ${KEYPAIR_NAME}"

# Create or check S3 bucket
echo ""
echo "Setting up S3 bucket for template hosting..."
if aws s3 ls "s3://${BUCKET_NAME}" 2>/dev/null; then
    echo "✅ Bucket ${BUCKET_NAME} already exists"
else
    echo "Creating S3 bucket: ${BUCKET_NAME}"
    aws s3 mb "s3://${BUCKET_NAME}" --region ${REGION}

    # Enable public read access for template files
    aws s3api put-bucket-policy --bucket ${BUCKET_NAME} --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "PublicReadGetObject",
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'${BUCKET_NAME}'/*"
            }
        ]
    }'
    echo "✅ Bucket created and configured for public access"
fi

# Update template with instructor endpoints
echo ""
echo "Updating template with instructor endpoints..."
cp ${TEMPLATE_FILE} ${TEMPLATE_FILE}.tmp

# Update default values in template
# Note: Need to update EvaluationEndpoint and SubmissionEndpoint separately
sed -i "/EvaluationEndpoint:/,/Default:/{s|Default:.*|Default: '${EVALUATION_ENDPOINT}'|}" ${TEMPLATE_FILE}.tmp
sed -i "/SubmissionEndpoint:/,/Default:/{s|Default:.*|Default: '${SUBMISSION_ENDPOINT}'|}" ${TEMPLATE_FILE}.tmp
sed -i "/ApiKey:/,/Default:/{s|Default:.*|Default: '${API_KEY}'|}" ${TEMPLATE_FILE}.tmp
sed -i "/KeyPairName:/,/Default:/{s|Default:.*|Default: '${KEYPAIR_NAME}'|}" ${TEMPLATE_FILE}.tmp

# Upload template to S3
echo "Uploading template to S3..."
aws s3 cp ${TEMPLATE_FILE}.tmp "s3://${BUCKET_NAME}/${TEMPLATE_FILE}" --region ${REGION}

# Clean up temporary file
rm ${TEMPLATE_FILE}.tmp

# Generate the quick deploy URL
TEMPLATE_URL="https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/${TEMPLATE_FILE}"
QUICK_DEPLOY_URL="https://${REGION}.console.aws.amazon.com/cloudformation/home?region=${REGION}#/stacks/create/review?templateURL=${TEMPLATE_URL}&stackName=${STACK_NAME_DEFAULT}"

echo ""
echo "=== Quick Deploy Link Created! ==="
echo ""
echo "📋 Template URL:"
echo "   ${TEMPLATE_URL}"
echo ""
echo "🚀 Quick Deploy Link:"
echo "   ${QUICK_DEPLOY_URL}"
echo ""
echo "📱 Shortened URL (create with bit.ly or similar):"
echo "   bit.ly/k8s-assessment"
echo ""

# Create HTML page with the link
cat > student-deploy-page.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Assessment - Quick Deploy</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            margin: 0;
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            font-size: 3em;
            margin-bottom: 10px;
        }
        h1 {
            color: #2d3748;
            margin-bottom: 10px;
        }
        .subtitle {
            color: #718096;
            font-size: 1.1em;
        }
        .deploy-button {
            display: block;
            width: 300px;
            margin: 30px auto;
            padding: 15px 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 10px;
            text-align: center;
            font-size: 1.2em;
            font-weight: bold;
            transition: transform 0.2s ease;
        }
        .deploy-button:hover {
            transform: translateY(-2px);
        }
        .instructions {
            background: #f7fafc;
            border-radius: 10px;
            padding: 20px;
            margin: 20px 0;
        }
        .step {
            margin: 15px 0;
            padding: 10px;
            background: white;
            border-radius: 5px;
            border-left: 4px solid #667eea;
        }
        .warning {
            background: #fff5f5;
            border: 1px solid #fc8181;
            border-radius: 5px;
            padding: 15px;
            margin: 20px 0;
            color: #c53030;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="logo">🎓</div>
            <h1>Kubernetes Assessment Framework</h1>
            <p class="subtitle">Deploy your personal k3s environment</p>
        </div>

        <a href="${QUICK_DEPLOY_URL}" class="deploy-button" target="_blank">
            🚀 Deploy My Environment
        </a>

        <div class="instructions">
            <h3>📋 Instructions</h3>

            <div class="step">
                <strong>Step 1:</strong> Click the "Deploy My Environment" button above
            </div>

            <div class="step">
                <strong>Step 2:</strong> In the CloudFormation console, enter your <strong>6-character Neptun Code</strong> (e.g., ABC123)
            </div>

            <div class="step">
                <strong>Step 3:</strong> Select your assigned task from the dropdown
            </div>

            <div class="step">
                <strong>Step 4:</strong> Click "Create Stack" and wait 5-10 minutes for deployment
            </div>

            <div class="step">
                <strong>Step 5:</strong> Get your SSH connection details from the "Outputs" tab
            </div>

            <div class="step">
                <strong>Step 6:</strong> SSH into your environment and complete the task!
            </div>
        </div>

        <div class="warning">
            <strong>⚠️ Important:</strong>
            <ul>
                <li>Your environment will auto-delete after 4 hours</li>
                <li>Save your work regularly</li>
                <li>Only one environment per Neptun Code</li>
                <li>Make sure to submit your results before the deadline</li>
            </ul>
        </div>

        <div class="instructions">
            <h3>🔧 What You'll Get</h3>
            <ul>
                <li>✅ Personal k3s Kubernetes cluster on EC2</li>
                <li>✅ Pre-configured development environment</li>
                <li>✅ Task-specific workspace and instructions</li>
                <li>✅ Evaluation and submission tools</li>
                <li>✅ SSH access with provided key pair</li>
            </ul>
        </div>

        <div class="instructions">
            <h3>📚 Available Tasks</h3>
            <div class="step">
                <strong>Task 01:</strong> Deploy NGINX Web Application<br>
                <small>Create a scalable NGINX deployment with resource limits</small>
            </div>
            <div class="step">
                <strong>Task 02:</strong> Service and Ingress Configuration<br>
                <small>Expose applications with services and ingress</small>
            </div>
            <div class="step">
                <strong>Task 03:</strong> ConfigMaps and Secrets<br>
                <small>Manage application configuration and secrets</small>
            </div>
        </div>
    </div>
</body>
</html>
EOF

echo "📱 Student page created: student-deploy-page.html"
echo ""

# Upload the student page to S3
aws s3 cp student-deploy-page.html "s3://${BUCKET_NAME}/index.html" --region ${REGION}
STUDENT_PAGE_URL="https://${BUCKET_NAME}.s3.${REGION}.amazonaws.com/index.html"

echo "🌐 Student Access Page:"
echo "   ${STUDENT_PAGE_URL}"
echo ""

echo "🎓 For Your Professor:"
echo ""
echo "Share this link with students:"
echo "   ${STUDENT_PAGE_URL}"
echo ""
echo "Or the direct CloudFormation link:"
echo "   ${QUICK_DEPLOY_URL}"
echo ""
echo "Students will:"
echo "1. Click the link"
echo "2. Enter their Neptun Code"
echo "3. Select their task"
echo "4. Get a personal k3s environment"
echo ""
echo "✅ Quick Deploy Link Setup Complete!"