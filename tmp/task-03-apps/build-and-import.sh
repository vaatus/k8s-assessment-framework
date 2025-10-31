#!/bin/bash
# Build and import task-03 container images to K3s

set -e

echo "========================================"
echo "Building Task-03 Container Images"
echo "========================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

echo "3. Importing backend to K3s..."
docker save backend:latest | sudo k3s ctr images import -
echo "   ✅ Backend imported to K3s"
echo ""

echo "4. Importing frontend to K3s..."
docker save frontend:latest | sudo k3s ctr images import -
echo "   ✅ Frontend imported to K3s"
echo ""

echo "5. Verifying images in K3s..."
sudo k3s ctr images ls | grep -E "backend|frontend"
echo ""

echo "========================================"
echo "✅ All images built and imported!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Deploy Kubernetes manifests: kubectl apply -f manifests.yaml"
echo "2. Wait for pods: kubectl wait --for=condition=ready pod -l app=backend -n task-03 --timeout=60s"
echo "3. Wait for pods: kubectl wait --for=condition=ready pod -l app=frontend -n task-03 --timeout=60s"
echo "4. Request evaluation: ~/student-tools/request-evaluation.sh task-03"
