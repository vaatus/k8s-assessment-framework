#!/bin/bash
set -e

echo "=== Fixing k3s Setup ==="

# Install AWS CLI first
echo "Installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip -y
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Wait for k3s to be fully ready
echo "Waiting for k3s service to be active..."
sudo systemctl status k3s --no-pager || true

echo "Checking if k3s is running..."
sudo systemctl is-active k3s || sudo systemctl start k3s

# Wait a bit more
echo "Waiting 30 seconds for k3s to initialize..."
sleep 30

# Set up kubectl access
echo "Setting up kubectl access..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Update server address in kubeconfig to use external IP
EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sed -i "s/127.0.0.1/${EXTERNAL_IP}/g" ~/.kube/config

echo "External IP: ${EXTERNAL_IP}"

# Test kubectl access
echo "Testing kubectl access..."
kubectl get nodes || {
    echo "kubectl not working, trying with k3s kubectl..."
    sudo k3s kubectl get nodes
}

# Check if nodes are ready
echo "Waiting for node to be ready..."
for i in {1..60}; do
    NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' || echo "NotReady")
    if [ "$NODE_STATUS" = "Ready" ]; then
        echo "✅ Node is ready!"
        break
    fi
    echo "Waiting for node to be ready... (attempt $i/60) Status: $NODE_STATUS"
    sleep 5
done

# Show cluster status
echo ""
echo "=== Cluster Status ==="
kubectl get nodes
kubectl get pods -A

echo ""
echo "=== k3s Setup Fixed ==="