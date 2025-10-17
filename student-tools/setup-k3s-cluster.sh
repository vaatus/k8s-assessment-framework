#!/bin/bash
set -e

echo "=== Setting up k3s Cluster on EC2 ==="

# Update system
sudo apt update -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y curl wget jq

# Install k3s
echo "Installing k3s..."
curl -sfL https://get.k3s.io | sh -

# Wait for k3s to be ready
echo "Waiting for k3s to be ready..."
sudo k3s kubectl wait --for=condition=ready node --all --timeout=300s

# Set up kubectl access for current user
echo "Setting up kubectl access..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Update server address in kubeconfig to use external IP
EXTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
sed -i "s/127.0.0.1/${EXTERNAL_IP}/g" ~/.kube/config

echo "External IP: ${EXTERNAL_IP}"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify cluster is working
echo "Verifying cluster..."
kubectl get nodes
kubectl get pods -A

# Install Kyverno
echo "Installing Kyverno..."
kubectl create -f https://github.com/kyverno/kyverno/releases/download/v1.10.0/install.yaml

# Wait for Kyverno to be ready
echo "Waiting for Kyverno to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s

echo ""
echo "=== k3s Cluster Setup Complete ==="
echo ""
echo "Cluster Details:"
echo "- External IP: ${EXTERNAL_IP}"
echo "- Kubeconfig: ~/.kube/config"
echo "- Access: kubectl get nodes"
echo ""
echo "Important: Make sure EC2 Security Group allows:"
echo "- Port 6443 (Kubernetes API) from instructor Lambda"
echo "- Port 22 (SSH) for your access"
echo ""
echo "Next steps:"
echo "1. Configure EC2 security group"
echo "2. Apply task policies"
echo "3. Create student-id.txt file"
echo "4. Copy endpoint files from instructor"