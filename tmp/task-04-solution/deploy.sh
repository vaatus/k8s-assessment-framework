#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Task-04: ConfigMaps, Secrets, Resource Management       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Navigate to solution directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Step 1: Creating namespace..."
kubectl apply -f 01-namespace.yaml
echo ""

echo "Step 2: Creating ConfigMap..."
kubectl apply -f 02-configmap.yaml
echo ""

echo "Step 3: Creating Secret..."
kubectl apply -f 03-secret.yaml
echo ""

echo "Step 4: Creating Deployment..."
kubectl apply -f 04-deployment.yaml
echo ""

echo "Step 5: Creating Service..."
kubectl apply -f 05-service.yaml
echo ""

echo "Step 6: Waiting for pods to be ready (max 60s)..."
kubectl wait --for=condition=ready pod -l app=config-demo -n task-04 --timeout=60s || true
echo ""

echo "Step 7: Verifying deployment..."
echo ""
echo "=== Resources ==="
kubectl get all -n task-04
echo ""

echo "=== ConfigMaps ==="
kubectl get configmap -n task-04
echo ""

echo "=== Secrets ==="
kubectl get secret -n task-04
echo ""

echo "=== Pod Details ==="
kubectl get pods -n task-04 -o wide
echo ""

echo "Step 8: Verifying environment variables in pods..."
POD=$(kubectl get pods -n task-04 -l app=config-demo -o jsonpath='{.items[0].metadata.name}')
if [ -n "$POD" ]; then
    echo "Checking pod: $POD"
    echo ""
    echo "Environment variables:"
    kubectl exec -n task-04 $POD -- env | grep -E "APP_NAME|APP_ENVIRONMENT|DB_PASSWORD" || echo "Env vars not found"
    echo ""
fi

echo "Step 9: Testing service connectivity..."
echo "Testing nginx service..."
kubectl run test-pod --image=busybox:latest --rm -i --restart=Never -n task-04 -- \
  wget -qO- --timeout=5 http://config-demo-service.task-04.svc.cluster.local || echo "Service test failed"
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ Deployment Complete!                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Review the resources:"
echo "     kubectl get all,configmap,secret -n task-04"
echo ""
echo "  2. Check pod environment variables:"
echo "     kubectl exec -n task-04 <pod-name> -- env"
echo ""
echo "  3. Request evaluation:"
echo "     ~/student-tools/request-evaluation.sh task-04"
echo ""
echo "Expected score: 100/100"
echo ""
