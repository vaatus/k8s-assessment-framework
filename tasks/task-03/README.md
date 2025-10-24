# Task 03: Health Probes and Graceful Shutdown

## Overview

In this task, you will implement a cloud-native web application with health probes, liveness checks, and graceful shutdown mechanisms. This task teaches essential patterns for building reliable, production-ready applications in Kubernetes.

## Learning Objectives

- Implement health check endpoints
- Configure startup and liveness probes
- Implement pod self-awareness
- Handle graceful shutdown with preStop hooks
- Understand service-to-service communication

## Requirements

Create a frontend and backend application with the following specifications:

### 1. Backend Service

**Deployment**:
- **Name**: `backend`
- **Replicas**: 1
- **Namespace**: `task-03`
- **Labels**: `app: backend`
- **Container Port**: 5000

**Endpoints**:
- `GET /get-config` - Returns configuration data
- `GET /ping` - Health check endpoint
- `POST /game-over` - Called during graceful shutdown

**Service**:
- **Name**: `svc-backend`
- **Type**: ClusterIP
- **Port**: 5000 → 5000

### 2. Frontend Service

**Deployment**:
- **Name**: `frontend`
- **Replicas**: 1
- **Namespace**: `task-03`
- **Labels**: `app: frontend`
- **Container Port**: 8080

**Endpoints**:
- `GET /startup` - Startup probe endpoint (calls backend /get-config)
- `GET /who-am-i` - Returns JSON with pod name and backend code
- `GET /health` - Liveness probe endpoint (checks backend /ping)

**Probes**:
- **Startup Probe**: HTTP GET /startup on port 8080
- **Liveness Probe**: HTTP GET /health on port 8080, period=5s, failureThreshold=3

**PreStop Hook**:
- Must call backend's `/game-over` endpoint before termination

**Service**:
- **Name**: `svc-frontend`
- **Type**: NodePort
- **Port**: 8080 → 8080

## Evaluation Criteria (100 points)

| Criterion | Points | Description |
|-----------|--------|-------------|
| **Backend Deployment** | 5 | Backend deployment exists |
| **Frontend Deployment** | 5 | Frontend deployment exists |
| **Backend Service** | 5 | Backend service exists |
| **Frontend Service** | 5 | Frontend service exists |
| **Backend /get-config** | 10 | Endpoint returns config data |
| **Backend /ping** | 10 | Ping endpoint works |
| **Frontend /startup** | 15 | Startup endpoint works and calls backend |
| **Frontend /who-am-i** | 15 | Returns pod name and backend code |
| **Frontend /health** | 10 | Health endpoint works |
| **Startup Probe Configured** | 10 | Startup probe correctly configured |
| **Liveness Probe Configured** | 10 | Liveness probe with correct parameters |
| **Graceful Shutdown** | 5 | PreStop hook calls backend /game-over |

## Implementation Guide

### Step 1: Create Namespace

```bash
kubectl create namespace task-03
```

### Step 2: Backend Application

Create `backend/app.py`:

```python
from flask import Flask, jsonify
import random

app = Flask(__name__)

# Generate config code
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
```

Create `backend/Dockerfile`:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask
COPY app.py .
CMD ["python", "app.py"]
```

Build and import to K3s:

```bash
docker build -t backend:latest backend/
docker save backend:latest | sudo k3s ctr images import -
```

### Step 3: Frontend Application

Create `frontend/app.py`:

```python
from flask import Flask, jsonify
import requests
import os
import signal
import sys

app = Flask(__name__)

# Backend configuration
BACKEND_URL = "http://svc-backend.task-03.svc.cluster.local:5000"
backend_code = None

@app.route('/startup')
def startup():
    """Startup probe - retrieve config from backend"""
    global backend_code
    try:
        # Retry logic for backend connection
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
    """Return pod name and backend code"""
    pod_name = os.environ.get('POD_NAME', 'unknown')
    return jsonify({
        'name': pod_name,
        'code': backend_code or 'not-initialized'
    })

@app.route('/health')
def health():
    """Liveness probe - check backend connection"""
    try:
        response = requests.get(f'{BACKEND_URL}/ping', timeout=5)
        if response.status_code == 200:
            return jsonify({'status': 'healthy'})
        return jsonify({'status': 'unhealthy'}), 500
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

def graceful_shutdown(signum, frame):
    """Handle shutdown signal"""
    print("Received shutdown signal, calling backend /game-over...")
    try:
        requests.post(f'{BACKEND_URL}/game-over', timeout=5)
        print("Successfully notified backend")
    except Exception as e:
        print(f"Error notifying backend: {e}")
    sys.exit(0)

# Register signal handlers
signal.signal(signal.SIGTERM, graceful_shutdown)
signal.signal(signal.SIGINT, graceful_shutdown)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

Create `frontend/Dockerfile`:

```dockerfile
FROM python:3.11-slim
WORKDIR /app
RUN pip install flask requests
COPY app.py .
CMD ["python", "app.py"]
```

Build and import:

```bash
docker build -t frontend:latest frontend/
docker save frontend:latest | sudo k3s ctr images import -
```

### Step 4: Kubernetes Manifests

Create `manifests.yaml`:

```yaml
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
        # Startup probe
        startupProbe:
          httpGet:
            path: /startup
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          failureThreshold: 3
        # Liveness probe
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
        # Graceful shutdown
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
```

### Step 5: Deploy and Test

```bash
# Deploy all resources
kubectl apply -f manifests.yaml

# Check deployments
kubectl get deployments -n task-03

# Check pods
kubectl get pods -n task-03

# Test backend
kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-03 -- \
  curl http://svc-backend:5000/get-config

# Test frontend
kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-03 -- \
  curl http://svc-frontend:8080/who-am-i
```

### Step 6: Test Graceful Shutdown

```bash
# Watch backend logs
kubectl logs -f deployment/backend -n task-03 &

# Delete frontend pod
kubectl delete pod -l app=frontend -n task-03

# Check backend logs for "Received game-over signal"
```

## Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-03
```

## Key Concepts

### Startup Probe
- Kubernetes waits for startup probe to succeed before starting liveness/readiness probes
- Useful for slow-starting applications
- Frontend waits for backend connection before marking itself as started

### Liveness Probe
- Kubernetes restarts container if liveness probe fails
- Used to detect when application is stuck or deadlocked
- Frontend checks backend connectivity

### Pod Self-Awareness
- Use Downward API to inject pod metadata as environment variables
- Access pod name, namespace, labels, etc.
- Frontend knows its own pod name

### Graceful Shutdown
- Use preStop hook to perform cleanup before termination
- Frontend notifies backend before shutting down
- Prevents abrupt connection terminations

## Common Issues

### Probes Failing
```bash
kubectl describe pod <frontend-pod> -n task-03
# Check Events section for probe failures
```

### Backend Not Reachable
```bash
# Test service DNS
kubectl run test --rm -it --image=busybox --restart=Never -n task-03 -- \
  nslookup svc-backend.task-03.svc.cluster.local
```

### PreStop Hook Not Working
```bash
# Check backend logs
kubectl logs deployment/backend -n task-03 --tail=50
```

## Additional Resources

- Kubernetes Patterns Book - Health Probe chapter
- [Kubernetes Probes Documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Downward API](https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/)

Good luck! 🚀
