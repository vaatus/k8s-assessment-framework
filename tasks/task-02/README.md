# Task 02: StatefulSet with Persistent Storage

## Overview

In this task, you will create a StatefulSet for a key-value store application with persistent storage using PersistentVolumeClaims.

## Learning Objectives

- Understand StatefulSets and their use cases
- Configure PersistentVolumeClaims for stateful applications
- Work with headless services for stable network identities
- Implement data persistence across pod restarts

## Requirements

Create a Stateful application with the following specifications:

### 1. StatefulSet Configuration

- **Name**: `key-value-svc`
- **Replicas**: 4
- **Namespace**: `task-02`
- **Labels**: `app: key-value`

### 2. Container Specifications

- **Container Name**: `app`
- **Image**: Your key-value store application image
- **Port**: 5000

### 3. Persistent Storage

- **VolumeClaimTemplate Name**: `data`
- **Storage**: At least 1Mi
- **Purpose**: Store key-value pairs persistently

### 4. Headless Service

- **Name**: `key-value-headless`
- **Type**: ClusterIP
- **ClusterIP**: None (headless)
- **Selector**: `app: key-value`
- **Purpose**: Enable pod-to-pod communication with stable DNS names

## Application Endpoints

Your key-value store application should implement:

- `POST /obj/<key>` - Store a value under the given key
- `GET /obj/<key>` - Retrieve the value for the given key
- `GET /location/<key>` - Return which pod stores the given key

## Evaluation Criteria (100 points)

| Criterion | Points | Description |
|-----------|--------|-------------|
| **StatefulSet Exists** | 15 | StatefulSet 'key-value-svc' created |
| **Replica Count** | 10 | Exactly 4 replicas configured |
| **PVCs Created** | 15 | PersistentVolumeClaims exist for all pods |
| **Headless Service** | 10 | Headless service exists and is configured correctly |
| **Pods Running** | 10 | All 4 pods are in Running state |
| **Store Data** | 10 | Can store data via POST /obj/<key> |
| **Retrieve Data** | 10 | Can retrieve stored data via GET /obj/<key> |
| **Data Persistence** | 20 | Data survives pod restart |

## Getting Started

### Step 1: Create the Namespace

```bash
kubectl create namespace task-02
```

### Step 2: Create StatefulSet Manifest

Create a file named `statefulset.yaml`:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: key-value-svc
  namespace: task-02
spec:
  serviceName: "key-value-headless"
  replicas: 4
  selector:
    matchLabels:
      app: key-value
  template:
    metadata:
      labels:
        app: key-value
    spec:
      containers:
      - name: app
        image: your-key-value-store:latest
        ports:
        - containerPort: 5000
          name: http
        volumeMounts:
        - name: data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Mi
```

### Step 3: Create Headless Service

Create a file named `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: key-value-headless
  namespace: task-02
spec:
  clusterIP: None  # Headless service
  selector:
    app: key-value
  ports:
  - port: 5000
    targetPort: 5000
    name: http
```

### Step 4: Deploy Your Solution

```bash
kubectl apply -f service.yaml
kubectl apply -f statefulset.yaml
```

### Step 5: Verify Deployment

```bash
# Check StatefulSet
kubectl get statefulset -n task-02

# Check Pods
kubectl get pods -n task-02

# Check PVCs
kubectl get pvc -n task-02

# Check Service
kubectl get service -n task-02
```

Expected output:
```
NAME             READY   AGE
key-value-svc    4/4     2m

NAME                READY   STATUS    RESTARTS   AGE
key-value-svc-0     1/1     Running   0          2m
key-value-svc-1     1/1     Running   0          2m
key-value-svc-2     1/1     Running   0          2m
key-value-svc-3     1/1     Running   0          2m

NAME                     STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
data-key-value-svc-0     Bound    pvc-xxx  1Mi        RWO            local-path     2m
data-key-value-svc-1     Bound    pvc-xxx  1Mi        RWO            local-path     2m
data-key-value-svc-2     Bound    pvc-xxx  1Mi        RWO            local-path     2m
data-key-value-svc-3     Bound    pvc-xxx  1Mi        RWO            local-path     2m

NAME                  TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
key-value-headless    ClusterIP   None         <none>        5000/TCP   2m
```

## Testing Your Application

### Test Data Storage (from within the cluster)

```bash
# Store a value
kubectl run -it --rm test --image=curlimages/curl --restart=Never -n task-02 -- \
  curl -X POST http://key-value-svc-0.key-value-headless.task-02.svc.cluster.local:5000/obj/testkey \
  -d "testvalue"

# Retrieve the value
kubectl run -it --rm test --image=curlimages/curl --restart=Never -n task-02 -- \
  curl http://key-value-svc-0.key-value-headless.task-02.svc.cluster.local:5000/obj/testkey
```

### Test Data Persistence

```bash
# Store data in pod-0
kubectl exec -n task-02 key-value-svc-0 -- \
  curl -X POST http://localhost:5000/obj/persisttest -d "mydata"

# Delete pod-0
kubectl delete pod key-value-svc-0 -n task-02

# Wait for pod to recreate
kubectl wait --for=condition=Ready pod/key-value-svc-0 -n task-02 --timeout=60s

# Check if data still exists
kubectl exec -n task-02 key-value-svc-0 -- \
  curl http://localhost:5000/obj/persisttest
# Should return: mydata
```

## Request Evaluation

Once your solution is deployed and tested:

```bash
~/student-tools/request-evaluation.sh task-02
```

Review the results. If you're satisfied with your score:

```bash
~/student-tools/submit-final.sh task-02
```

## Tips

1. **StatefulSet vs Deployment**: StatefulSets provide stable network identities and persistent storage
2. **Pod Naming**: StatefulSet pods are named predictably: `<statefulset-name>-<ordinal>`
3. **Headless Service**: Required for StatefulSets to provide stable DNS names
4. **PVC Lifecycle**: PVCs are not automatically deleted when you delete the StatefulSet
5. **Storage Class**: K3s provides `local-path` storage class by default

## Clean Up PVCs

When you're done, delete the StatefulSet AND the PVCs:

```bash
# Delete StatefulSet
kubectl delete statefulset key-value-svc -n task-02

# Delete PVCs
kubectl delete pvc -l app=key-value -n task-02
```

## Common Issues

### Pods Stuck in Pending

```bash
kubectl describe pod key-value-svc-0 -n task-02
```

Check for PVC binding issues or resource constraints.

### Data Not Persisting

Verify the volume mount path matches your application's data directory:
```bash
kubectl exec -n task-02 key-value-svc-0 -- ls -la /data
```

### Service Not Resolving

Test DNS resolution:
```bash
kubectl run -it --rm test --image=busybox --restart=Never -n task-02 -- \
  nslookup key-value-headless.task-02.svc.cluster.local
```

## Additional Resources

- [Kubernetes StatefulSets Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
- Kubernetes Patterns Book - Chapter 12: Stateful Service

## Questions?

If you encounter issues:
1. Check pod logs: `kubectl logs key-value-svc-0 -n task-02`
2. Describe resources: `kubectl describe statefulset key-value-svc -n task-02`
3. Verify PVC status: `kubectl get pvc -n task-02`

Good luck! 🚀
