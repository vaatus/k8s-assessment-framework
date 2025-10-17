#!/bin/bash
set -e

echo "=== Configuring EC2 Security Group for k3s ==="

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

echo "Instance ID: ${INSTANCE_ID}"
echo "Region: ${REGION}"

# Get security group
SECURITY_GROUP=$(aws ec2 describe-instances \
    --instance-ids ${INSTANCE_ID} \
    --region ${REGION} \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group: ${SECURITY_GROUP}"

# Add rule for Kubernetes API (port 6443) - open to world for Lambda access
echo "Adding rule for Kubernetes API (port 6443)..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 6443 \
    --cidr 0.0.0.0/0 \
    --region ${REGION} 2>/dev/null || echo "Rule already exists"

# Add rule for SSH if not present
echo "Ensuring SSH access (port 22)..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region ${REGION} 2>/dev/null || echo "SSH rule already exists"

# Add rule for NodePort services (30000-32767) - optional
echo "Adding NodePort range (30000-32767)..."
aws ec2 authorize-security-group-ingress \
    --group-id ${SECURITY_GROUP} \
    --protocol tcp \
    --port 30000-32767 \
    --cidr 0.0.0.0/0 \
    --region ${REGION} 2>/dev/null || echo "NodePort rule already exists"

echo ""
echo "=== Security Group Configuration Complete ==="
echo ""
echo "Configured ports:"
echo "- 22 (SSH)"
echo "- 6443 (Kubernetes API)"
echo "- 30000-32767 (NodePort services)"
echo ""
echo "Verify with: aws ec2 describe-security-groups --group-ids ${SECURITY_GROUP} --region ${REGION}"