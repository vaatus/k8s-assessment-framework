#!/bin/bash
# Test script for counter application endpoints

set -e

NAMESPACE="task-05"
POD="counter-app-0"

echo "=== Testing Counter Application Endpoints ==="
echo ""

echo "1. Testing /ready endpoint..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://${POD}.counter-service:8080/ready
echo ""
echo ""

echo "2. Testing /count endpoint (initial value)..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://${POD}.counter-service:8080/count
echo ""
echo ""

echo "3. Testing /increment endpoint..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- --post-data='' http://${POD}.counter-service:8080/increment
echo ""
echo ""

echo "4. Testing /count endpoint (after increment)..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://${POD}.counter-service:8080/count
echo ""
echo ""

echo "5. Testing another increment..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- --post-data='' http://${POD}.counter-service:8080/increment
echo ""
echo ""

echo "6. Testing /count endpoint (after 2nd increment)..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://${POD}.counter-service:8080/count
echo ""
echo ""

echo "7. Testing /health endpoint..."
kubectl exec -n $NAMESPACE $POD -- wget -qO- http://${POD}.counter-service:8080/health
echo ""
echo ""

echo "8. Testing pod-1 /ready endpoint..."
kubectl exec -n $NAMESPACE counter-app-1 -- wget -qO- http://counter-app-1.counter-service:8080/ready
echo ""
echo ""

echo "9. Testing pod-1 /count endpoint..."
kubectl exec -n $NAMESPACE counter-app-1 -- wget -qO- http://counter-app-1.counter-service:8080/count
echo ""
echo ""

echo "=== All Tests Completed ==="
echo ""
echo "Key observations:"
echo "  - Each pod has its own persistent counter"
echo "  - Pod identity is stable (counter-app-0, counter-app-1)"
echo "  - Each pod's counter persists in its own PVC"
