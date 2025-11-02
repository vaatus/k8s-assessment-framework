#!/bin/bash
#
# Task-05 Deployment Script
# Deploys StatefulSet with persistent storage counter application
#

set -e

echo "=========================================="
echo "Task-05: StatefulSet Deployment"
echo "=========================================="
echo ""

# Check if Docker image exists
echo "Checking for counter-app Docker image..."
if ! docker image inspect counter-app:latest &> /dev/null; then
    echo "❌ Error: counter-app:latest image not found"
    echo ""
    echo "Please build the Docker image first:"
    echo "  cd tasks/task-05/app"
    echo "  docker build -t counter-app:latest ."
    echo ""
    echo "For K3s, import the image:"
    echo "  docker save counter-app:latest | sudo k3s ctr images import -"
    echo ""
    exit 1
fi
echo "✅ Docker image found"
echo ""

# Deploy in order
echo "Step 1/3: Creating namespace..."
kubectl apply -f 01-namespace.yaml

echo ""
echo "Step 2/3: Creating headless service..."
kubectl apply -f 02-service.yaml

echo ""
echo "Step 3/3: Creating StatefulSet..."
kubectl apply -f 03-statefulset.yaml

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=counter -n task-05 --timeout=120s || true

echo ""
echo "Checking deployment status:"
kubectl get statefulset,service,pvc,pods -n task-05

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Check pod status:"
echo "   kubectl get pods -n task-05"
echo ""
echo "2. Test counter increment:"
echo "   kubectl exec -n task-05 counter-app-0 -- curl -X POST http://localhost:8080/increment"
echo ""
echo "3. Get counter value:"
echo "   kubectl exec -n task-05 counter-app-0 -- curl http://localhost:8080/count"
echo ""
echo "4. Request evaluation:"
echo "   ~/student-tools/request-evaluation.sh task-05"
echo ""
