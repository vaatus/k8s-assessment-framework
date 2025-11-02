# Task 05: StatefulSet with Persistent Storage

## Objective

Deploy a stateful counter application using Kubernetes StatefulSet with persistent storage. This task demonstrates understanding of:

- **StatefulSets** for applications requiring stable pod identities
- **Persistent Volume Claims (PVCs)** for data persistence
- **Init Containers** for initialization tasks
- **Headless Services** for StatefulSet pod discovery
- **Readiness Probes** for application health checking
- **Volume Mounts** for persistent data storage

## Requirements

### 1. Namespace
- Create namespace: `task-05`

### 2. StatefulSet: `counter-app`
- **Replicas**: 2
- **ServiceName**: `counter-service`
- **Selector Labels**: `app=counter`
- **Volume Claim Template**:
  - Name: `counter-data`
  - Storage: `100Mi`
  - Access Mode: `ReadWriteOnce`

### 3. Container: `counter`
- **Image**: `counter-app:latest` (build provided)
- **Port**: 8080
- **Volume Mount**:
  - Name: `counter-data`
  - Mount Path: `/data`
- **Environment Variable**:
  - `POD_NAME` from `metadata.name`
- **Readiness Probe**:
  - HTTP GET on `/ready` port 8080
  - Initial Delay: 5 seconds
  - Period: 3 seconds

### 4. Init Container: `init-counter`
- **Image**: `busybox:latest`
- **Command**: Create initial counter file
- **Volume Mount**:
  - Name: `counter-data`
  - Mount Path: `/data`

### 5. Service: `counter-service`
- **Type**: ClusterIP (Headless - `clusterIP: None`)
- **Selector**: `app=counter`
- **Port**: 8080 → 8080

## Application API

The counter application exposes these endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/ready` | GET | Readiness probe - returns 200 if initialized |
| `/count` | GET | Get current counter value (JSON) |
| `/increment` | POST | Increment counter by 1 |
| `/reset` | POST | Reset counter to 0 |
| `/health` | GET | Health check |

### Response Format

**GET /count**:
```json
{
  "count": 5,
  "pod_name": "counter-app-0"
}
```

**POST /increment**:
```json
{
  "count": 6,
  "pod_name": "counter-app-0",
  "message": "Counter incremented"
}
```

## Building the Application

```bash
cd tasks/task-05/app
docker build -t counter-app:latest .

# For K3s
docker save counter-app:latest | sudo k3s ctr images import -
```

## Sample Solution

See `solution/` directory for:
- `statefulset.yaml` - StatefulSet and Service definitions
- `test-endpoints.sh` - Script to test the API endpoints

## Deployment Steps

1. **Create namespace**:
```bash
kubectl create namespace task-05
```

2. **Build and import application image**:
```bash
cd tasks/task-05/app
docker build -t counter-app:latest .
docker save counter-app:latest | sudo k3s ctr images import -
```

3. **Deploy StatefulSet and Service**:
```bash
kubectl apply -f solution/statefulset.yaml
```

4. **Verify deployment**:
```bash
# Check StatefulSet
kubectl get statefulset -n task-05

# Check pods
kubectl get pods -n task-05

# Check PVCs
kubectl get pvc -n task-05

# Check service
kubectl get svc -n task-05
```

5. **Test endpoints**:
```bash
# Test counter-app-0
kubectl exec -n task-05 counter-app-0 -- wget -qO- http://counter-app-0.counter-service:8080/count

# Increment counter
kubectl exec -n task-05 counter-app-0 -- wget -qO- --post-data='' http://counter-app-0.counter-service:8080/increment

# Check readiness
kubectl exec -n task-05 counter-app-0 -- wget -qO- http://counter-app-0.counter-service:8080/ready
```

## Evaluation Criteria

| Criterion | Points | Description |
|-----------|--------|-------------|
| StatefulSet exists | 15 | StatefulSet 'counter-app' created |
| Replicas correct | 10 | StatefulSet has 2 replicas |
| Pods ready | 10 | All pods in Running state |
| PVCs created | 5 | Persistent Volume Claims exist |
| Service exists | 10 | Headless service 'counter-service' created |
| Counter increment | 10 | POST /increment returns 200 |
| Counter get value | 10 | GET /count returns JSON |
| Pod-0 ready | 10 | GET /ready on pod-0 returns 200 |
| Pod-1 ready | 10 | GET /ready on pod-1 returns 200 |
| Readiness probe | 10 | Readiness probe configured |
| **Total** | **100** | |

## Key Concepts

### StatefulSet vs Deployment

**StatefulSet** provides:
- Stable, unique pod identities (e.g., `counter-app-0`, `counter-app-1`)
- Stable, persistent storage per pod
- Ordered, graceful deployment and scaling
- Ordered, automated rolling updates

**Use cases**: Databases, distributed systems, applications requiring stable network identities

### Headless Service

A service with `clusterIP: None` creates DNS records for each pod:
- `counter-app-0.counter-service.task-05.svc.cluster.local`
- `counter-app-1.counter-service.task-05.svc.cluster.local`

### Persistent Volume Claims in StatefulSets

StatefulSets use **volumeClaimTemplates** to automatically create a PVC for each pod:
- `counter-data-counter-app-0`
- `counter-data-counter-app-1`

Each pod gets its own persistent storage that persists across pod restarts.

## Testing

Request evaluation:
```bash
~/student-tools/request-evaluation.sh task-05
```

Expected score: **100/100**

## Troubleshooting

**Pods not starting?**
```bash
kubectl describe pod counter-app-0 -n task-05
kubectl logs counter-app-0 -n task-05
```

**PVC not binding?**
```bash
kubectl get pvc -n task-05
kubectl describe pvc counter-data-counter-app-0 -n task-05
```

**Readiness probe failing?**
```bash
kubectl logs counter-app-0 -n task-05
kubectl exec -n task-05 counter-app-0 -- ls -la /data/
```

**Init container failed?**
```bash
kubectl logs counter-app-0 -n task-05 -c init-counter
```

## Cleanup

```bash
kubectl delete namespace task-05
```

Note: PVCs and PVs may need manual cleanup:
```bash
kubectl delete pvc -n task-05 --all
```
