# Task-05 Solution: StatefulSet with Persistent Storage

## Overview

This solution demonstrates:
- ✅ StatefulSet with stable pod identities (counter-app-0, counter-app-1)
- ✅ Persistent Volume Claims for data storage (100Mi per pod)
- ✅ Init containers for counter file initialization
- ✅ HTTP API endpoints (/increment, /count, /ready, /health)
- ✅ Readiness probes (HTTP GET /ready)
- ✅ Volume mounts for persistent data (/data)
- ✅ Headless service for StatefulSet DNS
- ✅ File locking for concurrent counter access

## Prerequisites

### Build and Import Docker Image

The counter application requires a custom Docker image. Build it first:

```bash
# Navigate to the app directory
cd tasks/task-05/app

# Build the Docker image
docker build -t counter-app:latest .

# For K3s clusters, import the image
docker save counter-app:latest | sudo k3s ctr images import -

# Verify image is available
sudo k3s ctr images ls | grep counter-app
```

**Important**: The deployment will fail if the image is not available in K3s.

## Quick Deploy

### Option 1: All-in-One File
```bash
kubectl apply -f task-05-complete.yaml
```

### Option 2: Automated Script
```bash
./deploy.sh
```

### Option 3: Manual Step-by-Step
```bash
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-service.yaml
kubectl apply -f 03-statefulset.yaml
```

## Files Included

```
task-05-solution/
├── README.md                    # This file
├── task-05-complete.yaml        # All-in-one manifest
├── deploy.sh                    # Automated deployment script
├── 01-namespace.yaml            # Namespace creation
├── 02-service.yaml              # Headless service for StatefulSet
└── 03-statefulset.yaml          # StatefulSet with PVCs and init containers
```

## Resource Details

### Namespace: `task-05`
Isolated namespace for the task.

### Headless Service: `counter-service`
- **Type**: ClusterIP with clusterIP: None (headless)
- **Purpose**: Provides stable DNS names for StatefulSet pods
  - `counter-app-0.counter-service.task-05.svc.cluster.local`
  - `counter-app-1.counter-service.task-05.svc.cluster.local`
- **Port**: 8080 → 8080
- **Selector**: app=counter

### StatefulSet: `counter-app`
- **Replicas**: 2
- **Service Name**: counter-service (for stable DNS)
- **Pod Names**: counter-app-0, counter-app-1
- **Image**: counter-app:latest (custom Flask application)
- **Labels**: app=counter

#### Init Container: `init-counter`
- **Image**: busybox:latest
- **Purpose**: Initialize counter file at /data/counter.txt with value 0
- **Volume**: counter-data mounted at /data
- **Behavior**: Only creates file if it doesn't exist (persistent across restarts)

#### Main Container: `counter`
- **Image**: counter-app:latest
- **Port**: 8080
- **Environment Variables**:
  - `POD_NAME`: Injected from pod metadata (for identification)
- **Volume Mount**: counter-data at /data
- **Readiness Probe**:
  - HTTP GET /ready on port 8080
  - Initial delay: 5 seconds
  - Period: 3 seconds
  - Failure threshold: 3

#### Volume Claim Templates
- **Name**: counter-data
- **Access Mode**: ReadWriteOnce
- **Storage**: 100Mi
- **Creates**: One PVC per pod (counter-data-counter-app-0, counter-data-counter-app-1)

## Application Endpoints

The counter application (app.py) provides these endpoints:

| Endpoint | Method | Description | Response |
|----------|--------|-------------|----------|
| `/ready` | GET | Readiness check (file exists) | `{"status": "ready", "pod_name": "counter-app-0"}` |
| `/health` | GET | Health check | `{"status": "healthy", "pod_name": "counter-app-0"}` |
| `/count` | GET | Get current counter value | `{"count": 5, "pod_name": "counter-app-0"}` |
| `/increment` | POST | Increment counter by 1 | `{"count": 6, "pod_name": "counter-app-0", "message": "Counter incremented"}` |
| `/reset` | POST | Reset counter to 0 | `{"count": 0, "pod_name": "counter-app-0", "message": "Counter reset"}` |

## Verification

### Check all resources
```bash
kubectl get all,pvc -n task-05
```

Expected output:
```
NAME                READY   STATUS    RESTARTS   AGE
pod/counter-app-0   1/1     Running   0          2m
pod/counter-app-1   1/1     Running   0          2m

NAME                       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
service/counter-service    ClusterIP   None         <none>        8080/TCP   2m

NAME                           READY   AGE
statefulset.apps/counter-app   2/2     2m

NAME                                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES
persistentvolumeclaim/counter-data-counter-app-0   Bound    pvc-xxxxx   100Mi      RWO
persistentvolumeclaim/counter-data-counter-app-1   Bound    pvc-yyyyy   100Mi      RWO
```

### Check pod readiness
```bash
kubectl get pods -n task-05
```

Both pods should show `1/1` READY and `Running` STATUS.

### Check init container logs
```bash
kubectl logs -n task-05 counter-app-0 -c init-counter
```

Should show:
```
Initializing counter to 0
total 4
drwxr-xr-x    2 root     root            60 ...
-rw-r--r--    1 root     root             2 ... counter.txt
```

### Check application container logs
```bash
kubectl logs -n task-05 counter-app-0 -c counter
```

Should show:
```
Starting counter app on pod: counter-app-0
Counter file: /data/counter.txt
Initial count: 0
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:8080
```

### Test readiness endpoint
```bash
kubectl exec -n task-05 counter-app-0 -- curl -s http://localhost:8080/ready
```

Expected: `{"pod_name":"counter-app-0","status":"ready"}`

### Test counter increment
```bash
# Increment counter on pod-0
kubectl exec -n task-05 counter-app-0 -- curl -s -X POST http://localhost:8080/increment

# Get counter value
kubectl exec -n task-05 counter-app-0 -- curl -s http://localhost:8080/count
```

Expected: `{"count":1,"pod_name":"counter-app-0"}`

### Test data persistence
```bash
# Increment counter multiple times
kubectl exec -n task-05 counter-app-0 -- curl -s -X POST http://localhost:8080/increment
kubectl exec -n task-05 counter-app-0 -- curl -s -X POST http://localhost:8080/increment
kubectl exec -n task-05 counter-app-0 -- curl -s -X POST http://localhost:8080/increment

# Check value
kubectl exec -n task-05 counter-app-0 -- curl -s http://localhost:8080/count
# Should show: {"count":3,"pod_name":"counter-app-0"}

# Delete the pod to trigger restart
kubectl delete pod -n task-05 counter-app-0

# Wait for pod to restart
kubectl wait --for=condition=ready pod/counter-app-0 -n task-05 --timeout=60s

# Check value again (should persist)
kubectl exec -n task-05 counter-app-0 -- curl -s http://localhost:8080/count
# Should still show: {"count":3,"pod_name":"counter-app-0"}
```

### Verify each pod has its own counter
```bash
# Increment pod-0 counter
kubectl exec -n task-05 counter-app-0 -- curl -s -X POST http://localhost:8080/increment
kubectl exec -n task-05 counter-app-0 -- curl -s http://localhost:8080/count
# Shows: {"count":1,"pod_name":"counter-app-0"}

# Pod-1 has its own counter starting at 0
kubectl exec -n task-05 counter-app-1 -- curl -s http://localhost:8080/count
# Shows: {"count":0,"pod_name":"counter-app-1"}
```

### Test headless service DNS
```bash
# Test DNS resolution
kubectl run -n task-05 test-dns --image=busybox:latest --rm -i --restart=Never -- \
  nslookup counter-app-0.counter-service.task-05.svc.cluster.local

# Test HTTP access via DNS
kubectl run -n task-05 test-http --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://counter-app-0.counter-service.task-05.svc.cluster.local:8080/health
```

## Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-05
```

## Expected Score: 100/100

### Scoring Breakdown:
- ✅ StatefulSet exists: 15 points
- ✅ 2 replicas: 10 points
- ✅ All pods running: 10 points
- ✅ Volume claim templates: 5 points
- ✅ Headless service exists: 10 points
- ✅ Counter increment endpoint: 10 points
- ✅ Counter get value endpoint: 10 points
- ✅ Pod-0 readiness check: 10 points
- ✅ Pod-1 readiness check: 20 points

**Total: 100/100** 🎉

## Cleanup

```bash
# Delete all resources (including PVCs)
kubectl delete namespace task-05

# Verify PVCs are deleted
kubectl get pvc -n task-05
```

**Note**: Deleting the namespace will also delete the PersistentVolumeClaims and their data.

## Key Concepts Demonstrated

### 1. StatefulSets
StatefulSets provide:
- **Stable pod identities**: Pods named counter-app-0, counter-app-1 (not random names)
- **Ordered deployment**: Pods created sequentially (0, then 1)
- **Stable storage**: Each pod gets its own dedicated PVC
- **Stable DNS names**: Accessible via `<pod-name>.<service-name>.<namespace>.svc.cluster.local`

### 2. Persistent Volume Claims
Each pod gets its own PVC:
- `counter-data-counter-app-0` for pod-0
- `counter-data-counter-app-1` for pod-1

Data persists across pod restarts, rescheduling, and updates.

### 3. Init Containers
Run before main container starts:
- Initialize counter file if it doesn't exist
- Ensures application has required file structure
- Only runs once per pod creation (not on restarts)

### 4. Headless Services (clusterIP: None)
No load balancing, returns all pod IPs:
- Enables direct pod-to-pod communication
- Provides stable DNS names for StatefulSet pods
- Required for StatefulSet stable network identity

### 5. Readiness Probes
Kubernetes uses readiness probes to:
- Determine when a pod is ready to accept traffic
- Remove unready pods from service endpoints
- Prevent traffic to pods that aren't ready

### 6. Volume Mounts
Persistent storage mounted at `/data`:
- Survives pod restarts
- Enables stateful applications
- Each pod has its own isolated storage

### 7. Environment Variable Injection
`POD_NAME` injected from pod metadata:
```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
```

## Troubleshooting

### POST /increment returns 500 error (CRITICAL FIX)

**Problem**: The init container creates `/data/counter.txt` as root, but the main container runs as `appuser` (UID 1000) and cannot write to it.

**Symptoms**:
```bash
kubectl run -n task-05 test-post --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -X POST http://counter-app-0.counter-service:8080/increment
# Returns: 500 Internal Server Error
```

**Solution**: The init container must set proper ownership:
```yaml
# Set ownership to UID 1000 (appuser in the main container)
chown 1000:1000 /data/counter.txt
chmod 644 /data/counter.txt
```

**How to Apply Fix**:
```bash
# Delete StatefulSet (keeps PVCs)
kubectl delete statefulset -n task-05 counter-app

# Apply fixed manifest
kubectl apply -f 03-statefulset.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app=counter -n task-05 --timeout=120s

# Test POST again
kubectl exec -n task-05 counter-app-0 -c counter -- sh -c "wget -qO- --post-data='' http://localhost:8080/increment"
```

**Verify Fix**:
```bash
# Check init container logs for "Permissions set:"
kubectl logs -n task-05 counter-app-0 -c init-counter

# Should show:
# Permissions set:
# -rw-r--r--    1 1000     1000             2 ... counter.txt
```

### Pods stuck in Pending
```bash
kubectl describe pod -n task-05 counter-app-0
```
Check for PVC binding issues or insufficient storage.

### Pods not ready
```bash
kubectl logs -n task-05 counter-app-0 -c counter
```
Check if counter file exists and readiness probe is passing.

### Image pull errors
```bash
kubectl describe pod -n task-05 counter-app-0
```
Ensure image is built and imported to K3s:
```bash
docker save counter-app:latest | sudo k3s ctr images import -
```

### PVC not binding
```bash
kubectl get pvc -n task-05
kubectl describe pvc counter-data-counter-app-0 -n task-05
```
Check if storage class is available and provisioner is working.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Namespace: task-05                     │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │  Headless Service: counter-service                 │    │
│  │  - clusterIP: None                                 │    │
│  │  - Provides stable DNS for pods                    │    │
│  └────────────────────────────────────────────────────┘    │
│                          │                                  │
│         ┌────────────────┴────────────────┐                │
│         │                                 │                │
│  ┌──────▼─────────┐              ┌───────▼────────┐       │
│  │ counter-app-0  │              │ counter-app-1  │       │
│  │ ┌────────────┐ │              │ ┌────────────┐ │       │
│  │ │init-counter│ │              │ │init-counter│ │       │
│  │ │(busybox)   │ │              │ │(busybox)   │ │       │
│  │ └─────┬──────┘ │              │ └─────┬──────┘ │       │
│  │       │        │              │       │        │       │
│  │ ┌─────▼──────┐ │              │ ┌─────▼──────┐ │       │
│  │ │  counter   │ │              │ │  counter   │ │       │
│  │ │  (Flask)   │ │              │ │  (Flask)   │ │       │
│  │ │  :8080     │ │              │ │  :8080     │ │       │
│  │ └─────┬──────┘ │              │ └─────┬──────┘ │       │
│  │       │        │              │       │        │       │
│  │ ┌─────▼──────┐ │              │ ┌─────▼──────┐ │       │
│  │ │counter-data│ │              │ │counter-data│ │       │
│  │ │PVC (100Mi) │ │              │ │PVC (100Mi) │ │       │
│  │ │/data       │ │              │ │/data       │ │       │
│  │ └────────────┘ │              │ └────────────┘ │       │
│  └────────────────┘              └────────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## References

- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
