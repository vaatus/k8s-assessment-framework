# Task 04: ConfigMaps, Secrets, and Resource Management

## Overview

In this task, you will learn how to externalize configuration and manage secrets in Kubernetes while properly setting resource constraints for your applications.

## Learning Objectives

- Create and use ConfigMaps for application configuration
- Manage sensitive data with Secrets
- Set resource requests and limits
- Inject configuration via environment variables
- Understand the difference between ConfigMaps and Secrets

## 🎯 Requirements

### Deployment Requirements
- **Name**: `config-demo-app`
- **Replicas**: 2
- **Namespace**: `task-04`
- **Labels**: `app: config-demo`
- **Image**: `nginx:latest` (any nginx version)
- **Port**: 80

### ConfigMap Requirements
Create a ConfigMap named `app-config` with:
- Key: `app.name` → Value: Your application name
- Key: `app.environment` → Value: "production" or "development"

### Secret Requirements
Create a Secret named `app-secrets` with:
- Key: `db-password` → Value: A database password (base64 encoded)

### Environment Variables
Your deployment must inject:
- `APP_NAME` from ConfigMap key `app.name`
- `DB_PASSWORD` from Secret key `db-password`

### Resource Requirements
Set resource limits and requests:
- **CPU Request**: 100m (minimum)
- **Memory Request**: 64Mi (minimum)
- **CPU Limit**: 200m (maximum)
- **Memory Limit**: 128Mi (maximum)

### Service Requirements
- **Name**: `config-demo-service`
- **Type**: ClusterIP
- **Port**: 80 → 80

## 🔧 Getting Started

### Step 1: Create the Namespace

```bash
kubectl create namespace task-04
```

### Step 2: Understand ConfigMaps

**ConfigMaps** store non-sensitive configuration data as key-value pairs.

**When to use ConfigMaps:**
- Application configuration files
- Command-line arguments
- Environment variables
- Configuration data that changes between environments

**Create a ConfigMap (imperative)**:
```bash
kubectl create configmap app-config \
  --from-literal=app.name=MyApp \
  --from-literal=app.environment=production \
  -n task-04
```

**Or create from YAML (declarative)**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: task-04
data:
  app.name: "MyApp"
  app.environment: "production"
```

**Verify**:
```bash
kubectl get configmap app-config -n task-04 -o yaml
```

### Step 3: Understand Secrets

**Secrets** store sensitive data like passwords, tokens, and keys. Data is base64 encoded (not encrypted!).

**Create a Secret (imperative)**:
```bash
kubectl create secret generic app-secrets \
  --from-literal=db-password=SuperSecret123 \
  -n task-04
```

**Or create from YAML (declarative)**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: task-04
type: Opaque
data:
  db-password: U3VwZXJTZWNyZXQxMjM=  # base64 encoded
```

**Note**: To base64 encode a string:
```bash
echo -n "SuperSecret123" | base64
```

**Verify**:
```bash
kubectl get secret app-secrets -n task-04 -o yaml
```

### Step 4: Create Your Deployment

Your deployment needs to:
1. Use nginx image
2. Set 2 replicas
3. Configure resource limits and requests
4. Inject environment variables from ConfigMap and Secret

**Key concepts for environment variables**:

**From ConfigMap**:
```yaml
env:
- name: APP_NAME
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: app.name
```

**From Secret**:
```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-secrets
      key: db-password
```

**Resource constraints**:
```yaml
resources:
  requests:
    cpu: "100m"      # Minimum CPU
    memory: "64Mi"   # Minimum memory
  limits:
    cpu: "200m"      # Maximum CPU
    memory: "128Mi"  # Maximum memory
```

**What do these mean?**
- **Requests**: Guaranteed resources (scheduler uses this)
- **Limits**: Maximum resources (enforced by kubelet)
- **CPU**: Measured in millicores (1000m = 1 CPU core)
- **Memory**: Measured in bytes (Mi = Mebibytes)

### Step 5: Create the Service

Create a ClusterIP service to expose your deployment internally.

**Requirements**:
- Name: `config-demo-service`
- Type: ClusterIP
- Selector must match deployment labels
- Port 80 to targetPort 80

### Step 6: Deploy Your Resources

Deploy in this order:

```bash
# 1. Create ConfigMap
kubectl apply -f configmap.yaml

# 2. Create Secret
kubectl apply -f secret.yaml

# 3. Create Deployment (depends on ConfigMap and Secret)
kubectl apply -f deployment.yaml

# 4. Create Service
kubectl apply -f service.yaml
```

### Step 7: Verify Your Deployment

```bash
# Check all resources
kubectl get all -n task-04

# Check ConfigMap
kubectl get configmap -n task-04

# Check Secret
kubectl get secret -n task-04

# Describe deployment to see resource limits
kubectl describe deployment config-demo-app -n task-04

# Check if pods are running
kubectl get pods -n task-04
```

### Step 8: Verify Environment Variables

Check if environment variables were injected correctly:

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n task-04 -l app=config-demo -o jsonpath='{.items[0].metadata.name}')

# Check environment variables
kubectl exec -n task-04 $POD_NAME -- env | grep -E "APP_NAME|DB_PASSWORD"

# Should show:
# APP_NAME=MyApp
# DB_PASSWORD=SuperSecret123
```

### Step 9: Test the Service

```bash
# Test service connectivity
kubectl run test --rm -it --image=curlimages/curl --restart=Never -n task-04 -- \
  curl http://config-demo-service

# Should return nginx welcome page
```

## 🎓 Learning Resources

### ConfigMaps vs Secrets

| Feature | ConfigMap | Secret |
|---------|-----------|--------|
| **Purpose** | Non-sensitive config | Sensitive data |
| **Encoding** | Plain text | Base64 |
| **Security** | Not encrypted at rest | Not encrypted (by default) |
| **Use for** | App config, env settings | Passwords, tokens, keys |
| **Visibility** | Visible in kubectl get | Hidden in kubectl get |

### Resource Management

**Why set resource limits?**
- **Prevents resource starvation**: No single pod can consume all resources
- **Enables scheduling**: Kubernetes knows where to place pods
- **Quality of Service**: Determines QoS class (Guaranteed, Burstable, BestEffort)

**QoS Classes**:
- **Guaranteed**: requests == limits for all containers
- **Burstable**: requests < limits
- **BestEffort**: no requests or limits set

### Common Pitfalls

❌ **Forgetting to create ConfigMap/Secret before Deployment**
- Result: Pod fails to start (CrashLoopBackOff or CreateContainerConfigError)

❌ **Wrong key names in environment variable refs**
- Result: Pod starts but environment variable is empty

❌ **Not base64 encoding Secret data**
- Result: Secret creation fails or data is corrupted

❌ **Resource limits too low**
- Result: Pod gets OOMKilled (Out of Memory) or CPU throttled

## 📊 Evaluation Criteria (100 points)

| Criterion | Points | Check |
|-----------|--------|-------|
| **Deployment exists** | 15 | Deployment created |
| **Replicas correct** | 10 | Exactly 2 replicas |
| **Image correct** | 10 | Uses nginx image |
| **Resources set** | 20 | Limits and requests configured |
| **Labels correct** | 5 | Labels match selector |
| **Pods running** | 10 | All pods in Running state |
| **Service exists** | 10 | Service created |
| **ConfigMap exists** | 10 | ConfigMap with required keys |
| **Secret exists** | 10 | Secret exists |

## 🚀 Request Evaluation

When ready:

```bash
~/student-tools/request-evaluation.sh task-04
```

Review your score:

```bash
~/student-tools/submit-final.sh task-04
```

## 💡 Hints

<details>
<summary>Hint 1: ConfigMap in deployment</summary>

Use `configMapKeyRef` in the `valueFrom` section of environment variables:

```yaml
env:
- name: MY_ENV_VAR
  valueFrom:
    configMapKeyRef:
      name: my-configmap
      key: my-key
```

</details>

<details>
<summary>Hint 2: Secret in deployment</summary>

Use `secretKeyRef` similarly:

```yaml
env:
- name: MY_SECRET_VAR
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: my-secret-key
```

</details>

<details>
<summary>Hint 3: Base64 encoding</summary>

To encode a value for use in Secret YAML:

```bash
echo -n "your-secret-value" | base64
```

To decode:

```bash
echo "encoded-value" | base64 -d
```

</details>

<details>
<summary>Hint 4: Resource format</summary>

CPU:
- `100m` = 100 millicores = 0.1 CPU
- `1` = 1 CPU core

Memory:
- `64Mi` = 64 Mebibytes
- `128Mi` = 128 Mebibytes
- `1Gi` = 1 Gibibyte

</details>

## 🧹 Clean Up

```bash
kubectl delete namespace task-04
```

## 📚 Further Reading

- [ConfigMaps Documentation](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets Documentation](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

Good luck! 🎓
