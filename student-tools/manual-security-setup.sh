#!/bin/bash
set -e

echo "=== Manual Security Group Setup Guide ==="

# Get instance information manually
echo "Getting instance information..."

# Try to get instance ID
INSTANCE_ID=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "")
REGION=$(curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "")

if [ -n "$INSTANCE_ID" ] && [ -n "$REGION" ]; then
    echo "Instance ID: ${INSTANCE_ID}"
    echo "Region: ${REGION}"

    # Try AWS CLI if configured
    if command -v aws &> /dev/null && aws sts get-caller-identity &> /dev/null; then
        echo "AWS CLI is configured, attempting automatic setup..."

        SECURITY_GROUP=$(aws ec2 describe-instances \
            --instance-ids ${INSTANCE_ID} \
            --region ${REGION} \
            --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
            --output text 2>/dev/null || echo "")

        if [ -n "$SECURITY_GROUP" ]; then
            echo "Security Group: ${SECURITY_GROUP}"

            echo "Adding security group rules..."
            aws ec2 authorize-security-group-ingress \
                --group-id ${SECURITY_GROUP} \
                --protocol tcp \
                --port 6443 \
                --cidr 0.0.0.0/0 \
                --region ${REGION} 2>/dev/null && echo "✅ Added port 6443" || echo "Port 6443 rule may already exist"

            aws ec2 authorize-security-group-ingress \
                --group-id ${SECURITY_GROUP} \
                --protocol tcp \
                --port 22 \
                --cidr 0.0.0.0/0 \
                --region ${REGION} 2>/dev/null && echo "✅ Added port 22" || echo "Port 22 rule may already exist"

            echo "✅ Security group configured automatically"
        else
            echo "Could not get security group ID automatically"
        fi
    else
        echo "AWS CLI not configured or not working"
    fi
else
    echo "Could not get instance metadata"
fi

echo ""
echo "=== Manual Steps (if automatic setup failed) ==="
echo ""
echo "1. Go to AWS Console > EC2 > Security Groups"
echo "2. Find your instance's security group"
echo "3. Add these Inbound Rules:"
echo "   - Type: Custom TCP, Port: 6443, Source: 0.0.0.0/0 (Kubernetes API)"
echo "   - Type: SSH, Port: 22, Source: 0.0.0.0/0 (SSH access)"
echo "   - Type: Custom TCP, Port Range: 30000-32767, Source: 0.0.0.0/0 (NodePort services)"
echo ""
echo "4. Test connectivity:"
EXTERNAL_IP=$(cat external-ip.txt 2>/dev/null || echo "YOUR_EC2_PUBLIC_IP")
echo "   curl -k https://${EXTERNAL_IP}:6443/version"
echo ""
echo "=== Security Setup Complete ==="