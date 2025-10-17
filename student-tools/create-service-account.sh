#!/bin/bash
set -e

echo "=== Creating Service Account for Remote Evaluation ==="

# Create service account for evaluation access
kubectl create serviceaccount evaluator -n kube-system --dry-run=client -o yaml | kubectl apply -f -

# Create cluster role binding for evaluation access
kubectl create clusterrolebinding evaluator-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:evaluator \
  --dry-run=client -o yaml | kubectl apply -f -

# For k3s, create a token manually
echo "Creating service account token..."
kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: evaluator-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: evaluator
type: kubernetes.io/service-account-token
EOF

# Wait for token to be populated
echo "Waiting for token to be ready..."
for i in {1..30}; do
    TOKEN=$(kubectl get secret evaluator-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        break
    fi
    echo "Waiting for token... (attempt $i/30)"
    sleep 2
done

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get service account token"
    echo "Falling back to creating token with expiry..."
    TOKEN=$(kubectl create token evaluator -n kube-system --duration=8760h)
fi

# Get cluster endpoint
EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
CLUSTER_ENDPOINT="https://${EXTERNAL_IP}:6443"

echo ""
echo "=== Service Account Created ==="
echo ""
echo "Cluster Endpoint: ${CLUSTER_ENDPOINT}"
echo "Token Length: ${#TOKEN}"
echo ""
echo "Save these for evaluation requests:"
echo "CLUSTER_ENDPOINT=${CLUSTER_ENDPOINT}"
echo "CLUSTER_TOKEN=${TOKEN}"
echo ""

# Save to files for scripts to use
echo "${CLUSTER_ENDPOINT}" > cluster-endpoint.txt
echo "${TOKEN}" > cluster-token.txt

echo "Credentials saved to:"
echo "- cluster-endpoint.txt"
echo "- cluster-token.txt"
echo ""
echo "These files will be used automatically by request-evaluation.sh"