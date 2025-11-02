#!/bin/bash
# Complete Task-03 Setup Guide for EC2 Instance
# Run this script on the student EC2 instance

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Task-03 Complete Setup on EC2 Instance                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Check Docker
echo "Step 1: Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo "✅ Docker installed. Please log out and back in, then re-run this script."
    exit 0
else
    echo "✅ Docker is installed"
    docker --version
fi
echo ""

# Step 2: Check if we can run docker without sudo
if ! docker ps &> /dev/null; then
    echo "⚠️  Docker requires sudo or you need to log out/in for group changes"
    echo "   Run: sudo usermod -aG docker $USER"
    echo "   Then log out and back in"
    exit 1
fi

# Step 3: Create application directories
echo "Step 2: Creating application directories..."
mkdir -p ~/task-03-apps/backend ~/task-03-apps/frontend
echo "✅ Directories created"
echo ""

# Step 4: Create backend application
echo "Step 3: Creating backend application..."
cat > ~/task-03-apps/backend/app.py << 'EOF'
from flask import Flask, jsonify
import random

app = Flask(__name__)
CONFIG_CODE = f"BACKEND-{random.randint(1000, 9999)}"

@app.route('/get-config')
def get_config():
    return jsonify({'code': CONFIG_CODE, 'status': 'ready'})

@app.route('/ping')
def ping():
    return jsonify({'status': 'ok'})

@app.route('/game-over', methods=['POST'])
def game_over():
    print("Received game-over signal from frontend")
    return jsonify({'message': 'Goodbye!'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
EOF

cat > ~/task-03-apps/backend/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask
COPY app.py .
CMD ["python", "app.py"]
EOF
echo "✅ Backend app created"
echo ""

# Step 5: Create frontend application
echo "Step 4: Creating frontend application..."
cat > ~/task-03-apps/frontend/app.py << 'EOF'
from flask import Flask, jsonify
import requests
import os
import signal
import sys
import time

app = Flask(__name__)
BACKEND_URL = "http://svc-backend.task-03.svc.cluster.local:5000"
backend_code = None

@app.route('/startup')
def startup():
    global backend_code
    try:
        max_retries = 10
        for i in range(max_retries):
            try:
                response = requests.get(f'{BACKEND_URL}/get-config', timeout=5)
                if response.status_code == 200:
                    backend_code = response.json().get('code')
                    return jsonify({'status': 'ready', 'backend_code': backend_code})
            except requests.exceptions.RequestException:
                if i < max_retries - 1:
                    time.sleep(2)
                    continue
                raise
        return jsonify({'status': 'failed'}), 500
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/who-am-i')
def who_am_i():
    pod_name = os.environ.get('POD_NAME', 'unknown')
    return jsonify({'name': pod_name, 'code': backend_code or 'not-initialized'})

@app.route('/health')
def health():
    try:
        response = requests.get(f'{BACKEND_URL}/ping', timeout=5)
        if response.status_code == 200:
            return jsonify({'status': 'healthy'})
        return jsonify({'status': 'unhealthy'}), 500
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

def graceful_shutdown(signum, frame):
    print("Received shutdown signal, calling backend /game-over...")
    try:
        requests.post(f'{BACKEND_URL}/game-over', timeout=5)
        print("Successfully notified backend")
    except Exception as e:
        print(f"Error notifying backend: {e}")
    sys.exit(0)

signal.signal(signal.SIGTERM, graceful_shutdown)
signal.signal(signal.SIGINT, graceful_shutdown)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
EOF

cat > ~/task-03-apps/frontend/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests
COPY app.py .
CMD ["python", "app.py"]
EOF
echo "✅ Frontend app created"
echo ""

# Step 6: Build Docker images
echo "Step 5: Building Docker images (this will take a few minutes)..."
echo "   Building backend..."
cd ~/task-03-apps/backend
docker build -t backend:latest . -q
echo "   ✅ Backend built"

echo "   Building frontend..."
cd ~/task-03-apps/frontend
docker build -t frontend:latest . -q
echo "   ✅ Frontend built"
echo ""

# Step 7: Import to K3s
echo "Step 6: Importing images to K3s..."
docker save backend:latest | sudo k3s ctr images import -
docker save frontend:latest | sudo k3s ctr images import -
echo "✅ Images imported"
echo ""

# Step 8: Verify images
echo "Step 7: Verifying images in K3s..."
sudo k3s ctr images ls | grep -E "backend|frontend"
echo ""

# Step 9: Create namespace
echo "Step 8: Creating namespace..."
kubectl create namespace task-03 --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready"
echo ""

# Step 10: Create manifests
echo "Step 9: Creating Kubernetes manifests..."
cat > ~/task-03-manifests.yaml << 'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: task-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: backend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 5000
---
apiVersion: v1
kind: Service
metadata:
  name: svc-backend
  namespace: task-03
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 5000
    targetPort: 5000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: task-03
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 8080
        env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "python -c 'import requests; requests.post(\"http://svc-backend.task-03.svc.cluster.local:5000/game-over\")'"]
---
apiVersion: v1
kind: Service
metadata:
  name: svc-frontend
  namespace: task-03
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080
EOF
echo "✅ Manifests created at ~/task-03-manifests.yaml"
echo ""

# Step 11: Deploy
echo "Step 10: Deploying to Kubernetes..."
kubectl delete deployment backend frontend -n task-03 2>/dev/null || true
kubectl apply -f ~/task-03-manifests.yaml
echo "✅ Deployed"
echo ""

# Step 12: Wait for pods
echo "Step 11: Waiting for pods to be ready (may take 60 seconds)..."
kubectl wait --for=condition=ready pod -l app=backend -n task-03 --timeout=120s
kubectl wait --for=condition=ready pod -l app=frontend -n task-03 --timeout=120s
echo "✅ Pods ready"
echo ""

# Step 13: Show status
echo "Step 12: Checking deployment status..."
kubectl get pods -n task-03 -o wide
echo ""

# Step 14: Show logs
echo "Step 13: Recent logs..."
echo "Backend logs:"
kubectl logs -n task-03 -l app=backend --tail=5
echo ""
echo "Frontend logs:"
kubectl logs -n task-03 -l app=frontend --tail=5
echo ""

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ Task-03 Setup Complete!                              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Request evaluation:"
echo "     ~/student-tools/request-evaluation.sh task-03"
echo ""
echo "  2. Expected score: 100/100"
echo ""
echo "  3. Test graceful shutdown manually:"
echo "     kubectl delete pod -n task-03 -l app=frontend"
echo "     kubectl logs -n task-03 -l app=backend --tail=20 | grep game-over"
echo ""
