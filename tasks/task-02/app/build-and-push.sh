#!/bin/bash
set -e

echo "Building key-value store application..."

cd "$(dirname "$0")"

# Build the image
docker build -t key-value-store:latest .

echo "✅ Image built successfully!"
echo ""
echo "To use this image in K3s, you have two options:"
echo ""
echo "Option 1: Save and import to K3s (for local testing):"
echo "  docker save key-value-store:latest | sudo k3s ctr images import -"
echo ""
echo "Option 2: Push to Docker Hub (for production):"
echo "  docker tag key-value-store:latest YOUR_DOCKERHUB_USERNAME/key-value-store:latest"
echo "  docker push YOUR_DOCKERHUB_USERNAME/key-value-store:latest"
echo ""
