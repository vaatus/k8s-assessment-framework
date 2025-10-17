#!/bin/bash
set -e

echo "=== Manual k3s Setup (For Testing/Debugging) ==="
echo "Use this script if you need to manually set up k3s for demonstration"
echo ""

# Get external IP
EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "")
if [ -z "$EXTERNAL_IP" ]; then
    echo "⚠️  Could not get external IP from metadata service"
    read -p "Please enter your EC2 instance's public IP: " EXTERNAL_IP
fi

echo "External IP: $EXTERNAL_IP"

# Update system
echo "Updating system packages..."
sudo apt-get update -y
sudo apt-get install -y curl wget jq

# Install k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sudo systemctl enable k3s
sudo systemctl start k3s
sleep 30

# Set up kubectl access
echo "Setting up kubectl access..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Update kubeconfig with external IP
echo "Updating kubeconfig with external IP..."
sed -i "s/127.0.0.1/$EXTERNAL_IP/g" ~/.kube/config

# Verify cluster access
echo "Testing cluster access..."
kubectl get nodes

# Install Kyverno
echo "Installing Kyverno..."
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.10.0/install.yaml

# Wait for Kyverno
echo "Waiting for Kyverno to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=kyverno -n kyverno --timeout=300s

# Create service account
echo "Creating service account for evaluation..."
kubectl create serviceaccount evaluator -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create clusterrolebinding evaluator-binding --clusterrole=cluster-admin --serviceaccount=kube-system:evaluator --dry-run=client -o yaml | kubectl apply -f -

# Create service account token
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: evaluator-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: evaluator
type: kubernetes.io/service-account-token
EOF

# Wait for token
echo "Waiting for service account token..."
for i in {1..30}; do
    TOKEN=$(kubectl get secret evaluator-token -n kube-system -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        break
    fi
    echo "Waiting for token... (attempt $i/30)"
    sleep 2
done

if [ -z "$TOKEN" ]; then
    echo "Failed to get service account token, creating temporary one..."
    TOKEN=$(kubectl create token evaluator -n kube-system --duration=8760h)
fi

# Save credentials
echo "Saving cluster credentials..."
echo "https://$EXTERNAL_IP:6443" > cluster-endpoint.txt
echo "$TOKEN" > cluster-token.txt

# Create task namespace
echo "Creating task-01 namespace..."
kubectl create namespace task-01 --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "=== Manual Setup Complete ==="
echo ""
echo "Cluster Details:"
echo "  External IP: $EXTERNAL_IP"
echo "  API Endpoint: https://$EXTERNAL_IP:6443"
echo "  Kubeconfig: ~/.kube/config"
echo ""
echo "Files created:"
echo "  cluster-endpoint.txt"
echo "  cluster-token.txt"
echo ""
echo "Next steps:"
echo "1. Make sure security group allows port 6443"
echo "2. Copy endpoint files from instructor account"
echo "3. Test evaluation: ../student-tools/request-evaluation.sh task-01"
echo ""
echo "Security group rule needed:"
echo "  Type: Custom TCP, Port: 6443, Source: 0.0.0.0/0"