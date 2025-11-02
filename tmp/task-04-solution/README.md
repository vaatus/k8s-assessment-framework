# Task-04 Solution: ConfigMaps, Secrets, and Resource Management

## Overview

This solution demonstrates:
- ✅ ConfigMap usage for application configuration
- ✅ Secrets for sensitive data
- ✅ Resource limits and requests
- ✅ Environment variables from multiple sources
- ✅ Deployment with 2 replicas
- ✅ Service exposure

## Quick Deploy

### Option 1: All-in-One File
```bash
kubectl apply -f task-04-complete.yaml
```

### Option 2: Individual Files
```bash
./deploy.sh
```

### Option 3: Manual Step-by-Step
```bash
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secret.yaml
kubectl apply -f 04-deployment.yaml
kubectl apply -f 05-service.yaml
```

## Files Included

```
task-04-solution/
├── README.md                    # This file
├── task-04-complete.yaml        # All-in-one manifest
├── deploy.sh                    # Automated deployment script
├── 01-namespace.yaml            # Namespace creation
├── 02-configmap.yaml            # ConfigMap with app config
├── 03-secret.yaml               # Secret with sensitive data
├── 04-deployment.yaml           # Deployment with resources
└── 05-service.yaml              # Service to expose app
```

## Resource Details

### ConfigMap: `app-config`
Contains application configuration:
- `app.name`: "config-demo-application"
- `app.environment`: "production"

### Secret: `app-secrets`
Contains sensitive data:
- `db-password`: "super-secret-password-123"

### Deployment: `config-demo-app`
- **Replicas**: 2
- **Image**: nginx:latest
- **Labels**: app=config-demo
- **Environment Variables**:
  - `APP_NAME` (from ConfigMap)
  - `APP_ENVIRONMENT` (from ConfigMap)
  - `DB_PASSWORD` (from Secret)
- **Resources**:
  - Limits: 500m CPU, 256Mi memory
  - Requests: 100m CPU, 128Mi memory

### Service: `config-demo-service`
- **Type**: ClusterIP
- **Port**: 80 → 80
- **Selector**: app=config-demo

## Verification

### Check all resources
```bash
kubectl get all,configmap,secret -n task-04
```

### Check ConfigMap
```bash
kubectl describe configmap app-config -n task-04
```

### Check Secret
```bash
kubectl describe secret app-secrets -n task-04
```

### Check environment variables in pod
```bash
POD=$(kubectl get pods -n task-04 -l app=config-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n task-04 $POD -- env | grep -E "APP_NAME|APP_ENVIRONMENT|DB_PASSWORD"
```

Expected output:
```
APP_NAME=config-demo-application
APP_ENVIRONMENT=production
DB_PASSWORD=super-secret-password-123
```

### Check resource limits
```bash
kubectl describe deployment config-demo-app -n task-04
```

Look for:
```
    Limits:
      cpu:     500m
      memory:  256Mi
    Requests:
      cpu:        100m
      memory:     128Mi
```

### Test service
```bash
kubectl run test-pod --image=busybox:latest --rm -i --restart=Never -n task-04 -- \
  wget -qO- http://config-demo-service.task-04.svc.cluster.local
```

Should return nginx default page HTML.

## Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-04
```

## Expected Score: 100/100

### Scoring Breakdown:
- Deployment exists: 15 points ✅
- 2 replicas: 10 points ✅
- nginx image: 10 points ✅
- Resource limits: 20 points ✅
- Labels match: 5 points ✅
- Pods running: 10 points ✅
- Service exists: 10 points ✅
- ConfigMap exists: 10 points ✅
- Secret exists: 10 points ✅

**Total: 100/100** 🎉

## Cleanup

```bash
kubectl delete namespace task-04
```

## Key Concepts Demonstrated

### 1. ConfigMaps
Store non-sensitive configuration data as key-value pairs. Used for:
- Application settings
- Configuration files
- Environment-specific variables

### 2. Secrets
Store sensitive data (passwords, tokens, keys). Kubernetes:
- Base64 encodes secrets
- Can restrict access via RBAC
- Encrypts at rest (with encryption enabled)

### 3. Environment Variables from ConfigMaps/Secrets
```yaml
env:
- name: APP_NAME
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: app.name
```

### 4. Resource Limits and Requests
- **Requests**: Guaranteed resources (scheduling decision)
- **Limits**: Maximum resources (throttling/OOMKill)

Benefits:
- Prevents resource starvation
- Enables better scheduling
- Protects cluster stability

### 5. Labels and Selectors
- Deployment uses `app: config-demo` label
- Service selects pods with same label
- Enables loose coupling
