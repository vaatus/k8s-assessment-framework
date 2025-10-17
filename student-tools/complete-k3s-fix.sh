#!/bin/bash
set -e

echo "=== Complete k3s Fix ==="

# Fix kubeconfig permissions
echo "Fixing kubeconfig permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# Set up kubectl access with proper permissions
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Try multiple methods to get external IP
echo "Getting external IP..."
EXTERNAL_IP=""

# Method 1: Instance metadata service
EXTERNAL_IP=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "")

# Method 2: Check if we're getting a private IP instead
if [ -z "$EXTERNAL_IP" ]; then
    echo "Metadata service not available, trying alternative methods..."
    EXTERNAL_IP=$(curl -s --connect-timeout 5 http://checkip.amazonaws.com 2>/dev/null || echo "")
fi

# Method 3: Use ifconfig to get the main IP
if [ -z "$EXTERNAL_IP" ]; then
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')
fi

# If still no IP, prompt user
if [ -z "$EXTERNAL_IP" ]; then
    echo "Could not automatically detect external IP."
    echo "Please check your EC2 instance's public IP in the AWS console."
    read -p "Enter your EC2 instance's public IP: " EXTERNAL_IP
fi

echo "Using IP: ${EXTERNAL_IP}"

# Update kubeconfig with external IP
sed -i "s/127.0.0.1/${EXTERNAL_IP}/g" ~/.kube/config

# Test kubectl
echo "Testing kubectl..."
kubectl get nodes --no-headers || {
    echo "kubectl still not working, using k3s kubectl as fallback"
    alias kubectl='sudo k3s kubectl'
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
}

# Show current status
echo ""
echo "=== Current Cluster Status ==="
kubectl get nodes
kubectl get pods -A

# Save the external IP for later use
echo "${EXTERNAL_IP}" > external-ip.txt
echo "External IP saved to external-ip.txt"

echo ""
echo "=== k3s Fix Complete ==="
echo "External IP: ${EXTERNAL_IP}"
echo "Cluster API: https://${EXTERNAL_IP}:6443"
echo ""
echo "Next steps:"
echo "1. Configure security group to allow port 6443"
echo "2. Install Kyverno"
echo "3. Create service account for evaluation"