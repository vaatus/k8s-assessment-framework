#!/bin/bash
# Build task-03 images and save as tar files for S3 upload

set -e

echo "========================================"
echo "Building Task-03 Images for S3"
echo "========================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/dist"

mkdir -p "$OUTPUT_DIR"

echo "1. Building backend image..."
cd "$SCRIPT_DIR/backend"
docker build -t backend:latest .
echo "   ✅ Backend image built"
echo ""

echo "2. Building frontend image..."
cd "$SCRIPT_DIR/frontend"
docker build -t frontend:latest .
echo "   ✅ Frontend image built"
echo ""

echo "3. Saving backend image to tar..."
docker save backend:latest > "$OUTPUT_DIR/backend.tar"
echo "   ✅ Saved to $OUTPUT_DIR/backend.tar"
echo ""

echo "4. Saving frontend image to tar..."
docker save frontend:latest > "$OUTPUT_DIR/frontend.tar"
echo "   ✅ Saved to $OUTPUT_DIR/frontend.tar"
echo ""

echo "========================================"
echo "✅ Images ready for S3 upload!"
echo "========================================"
echo ""
echo "Files created:"
ls -lh "$OUTPUT_DIR"/*.tar
echo ""
echo "Upload to S3 with:"
echo "  aws s3 cp $OUTPUT_DIR/backend.tar s3://k8s-assessment-templates/docker-images/"
echo "  aws s3 cp $OUTPUT_DIR/frontend.tar s3://k8s-assessment-templates/docker-images/"
