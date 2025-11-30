#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Build and Upload Docker Images to S3                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

REGION="us-east-1"
TEMPLATES_BUCKET="k8s-assessment-templates"
IMAGES_PREFIX="docker-images"

# Check if we're in the correct directory
if [ ! -f "build-and-upload-images.sh" ]; then
    echo "Error: Please run this script from the instructor-tools directory"
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if bucket exists
if ! aws s3 ls "s3://${TEMPLATES_BUCKET}" 2>/dev/null; then
    echo "Error: Bucket ${TEMPLATES_BUCKET} does not exist"
    echo "Run deploy-complete-setup.sh first"
    exit 1
fi

echo "This script will:"
echo "  1. Build task-02 kvstore application image"
echo "  2. Build task-03 backend/frontend images (if available)"
echo "  3. Save images as tar files"
echo "  4. Upload to S3 for CloudFormation to download"
echo ""
echo "Note: test-runner image is now built locally on student EC2 instances"
echo "      to reduce S3 storage and transfer costs."
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Create temporary directory for image files
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: ${TEMP_DIR}"
echo ""

# ============================================================================
# Note: Test-Runner Image (SKIPPED - now built locally on student EC2)
# ============================================================================
echo "=== Test-Runner Image ==="
echo "⏭️  Skipping test-runner image (now built locally on student EC2)"
echo "   This reduces S3 storage costs and transfer bandwidth"
echo ""

# ============================================================================
# Build Task-02 KVStore Image
# ============================================================================
echo "=== Building Task-02 KVStore Image ==="
echo ""

cd ../tasks/task-02/app

if [ ! -f "Dockerfile" ]; then
    echo "Error: kvstore Dockerfile not found"
    exit 1
fi

echo "Building kvstore:latest..."
docker build -t kvstore:latest . --quiet

echo "Saving kvstore image to tar..."
docker save kvstore:latest -o ${TEMP_DIR}/kvstore.tar

IMAGE_SIZE=$(du -h ${TEMP_DIR}/kvstore.tar | cut -f1)
echo "✅ KVStore image saved (${IMAGE_SIZE})"
echo ""

cd ../../../instructor-tools

# ============================================================================
# Upload Images to S3
# ============================================================================
echo "=== Uploading Images to S3 ==="
echo ""

echo "Uploading kvstore.tar..."
aws s3 cp ${TEMP_DIR}/kvstore.tar \
    "s3://${TEMPLATES_BUCKET}/${IMAGES_PREFIX}/kvstore.tar" \
    --region ${REGION}

echo "✅ Images uploaded to S3"
echo ""

# ============================================================================
# Generate Image Manifest
# ============================================================================
echo "=== Creating Image Manifest ==="
echo ""

cat > ${TEMP_DIR}/images-manifest.json <<EOF
{
  "images": [
    {
      "name": "kvstore",
      "version": "latest",
      "s3_url": "https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/${IMAGES_PREFIX}/kvstore.tar",
      "description": "Key-value store application for task-02",
      "size": "$(stat -f%z ${TEMP_DIR}/kvstore.tar 2>/dev/null || stat -c%s ${TEMP_DIR}/kvstore.tar)",
      "updated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }
  ],
  "notes": "test-runner image is built locally on student EC2 instances to reduce S3 costs"
}
EOF

aws s3 cp ${TEMP_DIR}/images-manifest.json \
    "s3://${TEMPLATES_BUCKET}/${IMAGES_PREFIX}/manifest.json" \
    --region ${REGION}

echo "✅ Manifest uploaded"
echo ""

# ============================================================================
# Cleanup
# ============================================================================
echo "Cleaning up temporary files..."
rm -rf ${TEMP_DIR}

# ============================================================================
# Summary
# ============================================================================
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    Upload Complete! ✅                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Images uploaded to S3:"
echo "   - s3://${TEMPLATES_BUCKET}/${IMAGES_PREFIX}/kvstore.tar"
echo ""
echo "🔗 Public URLs:"
echo "   KVStore: https://${TEMPLATES_BUCKET}.s3.${REGION}.amazonaws.com/${IMAGES_PREFIX}/kvstore.tar"
echo ""
echo "💡 Cost Optimization:"
echo "   - test-runner image is built locally on each student EC2 instance"
echo "   - This eliminates S3 storage and transfer costs for the most commonly used image"
echo ""
echo "✅ CloudFormation will automatically download and import these images"
echo "   during EC2 instance initialization."
echo ""
