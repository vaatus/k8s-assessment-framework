# Task 02: StatefulSet with Persistent Storage

## Overview

In this task, you will create a **StatefulSet** for a key-value store application with persistent storage. Unlike Deployments, StatefulSets maintain stable network identities and persistent storage for each pod.

## Learning Objectives

- Understand StatefulSets and their use cases
- Configure PersistentVolumeClaims for stateful applications
- Work with headless services for stable network identities
- Implement data persistence across pod restarts

## 🎯 Requirements

Your task is to deploy a distributed key-value store with the following specifications:

### StatefulSet Requirements
- **Name**: `key-value-svc`
- **Replicas**: 4 pods
- **Namespace**: `task-02`
- **Labels**: `app: key-value`
- **Image**: `kvstore:latest` (pre-loaded in your cluster)
- **Port**: Container port 5000

### Storage Requirements
- Each pod must have its own persistent storage
- **Volume name**: `data`
- **Mount path**: `/data`
- **Minimum size**: 1Mi
- **Access mode**: ReadWriteOnce

### Service Requirements
- **Service name**: `key-value-headless`
- **Service type**: Headless (ClusterIP: None)
- **Purpose**: Enable stable DNS names for each pod

### Application Behavior
The key-value store application should:
- Store data via: `POST /obj/<key>`
- Retrieve data via: `GET /obj/<key>`
- Return location via: `GET /location/<key>`
- Persist data across pod restarts

## 📦 Pre-loaded Docker Image

A key-value store application image is **already available** in your K3s cluster:

```bash
# Verify the image is available
sudo k3s ctr images ls | grep kvstore
# Should show: docker.io/library/kvstore:latest
```

**Important**: When using this image, you must set `imagePullPolicy: Never` to use the local image instead of pulling from a registry.

## 🔧 Getting Started

### Step 1: Understand StatefulSets

StatefulSets are different from Deployments:
- **Stable Identity**: Pods have predictable names (e.g., `app-0`, `app-1`, `app-2`)
- **Ordered Deployment**: Pods are created in sequence (0, 1, 2, ...)
- **Persistent Storage**: Each pod gets its own PersistentVolumeClaim
- **Stable Network**: Each pod has a stable DNS name

**When to use StatefulSets:**
- Databases (PostgreSQL, MySQL, MongoDB)
- Distributed systems (Kafka, Elasticsearch, etcd)
- Applications requiring stable storage or network identity

### Step 2: Create the Namespace

```bash
kubectl create namespace task-02
```

### Step 3: Design Your Headless Service

A **headless service** (ClusterIP: None) doesn't load-balance traffic. Instead, it creates DNS records for each pod.

**DNS pattern for StatefulSet pods:**
```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

**Example for your task:**
```
key-value-svc-0.key-value-headless.task-02.svc.cluster.local
key-value-svc-1.key-value-headless.task-02.svc.cluster.local
key-value-svc-2.key-value-headless.task-02.svc.cluster.local
key-value-svc-3.key-value-headless.task-02.svc.cluster.local
```

**What you need to define:**
- `apiVersion`: v1
- `kind`: Service
- `metadata.name`: (the service name from requirements)
- `metadata.namespace`: task-02
- `spec.clusterIP`: None (makes it headless)
- `spec.selector`: Match your pod labels
- `spec.ports`: Define the port mapping

**Hint**: The selector must match the labels in your StatefulSet's pod template.

### Step 4: Design Your StatefulSet

A StatefulSet requires several key components:

#### A. Basic Metadata
- Define `apiVersion: apps/v1`
- Define `kind: StatefulSet`
- Set the name and namespace

#### B. Spec Configuration
- `serviceName`: Must match your headless service name
- `replicas`: How many pods you need
- `selector.matchLabels`: Must match pod template labels

#### C. Pod Template
This defines what each pod looks like:

**Labels**: Set in `template.metadata.labels`
- Must match the `selector.matchLabels`

**Container Configuration**:
- `name`: Give your container a name (e.g., "app")
- `image`: Use `kvstore:latest`
- `imagePullPolicy`: Must be `Never` (uses local image)
- `ports`: Expose containerPort 5000

**Environment Variables** (optional but useful):
- You can inject the pod name using the Downward API:
  ```yaml
  env:
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  ```

**Volume Mounts**:
- `name`: Reference the volume claim template name
- `mountPath`: Where to mount the storage inside the container

#### D. Volume Claim Templates

This is what makes StatefulSets unique! Each pod gets its own PersistentVolumeClaim.

**Structure**:
```yaml
volumeClaimTemplates:
- metadata:
    name: <volume-name>
  spec:
    accessModes: [ <access-mode> ]
    resources:
      requests:
        storage: <size>
```

**Access Modes**:
- `ReadWriteOnce` (RWO): Mount by single node (most common)
- `ReadOnlyMany` (ROX): Mount read-only by multiple nodes
- `ReadWriteMany` (RWX): Mount read-write by multiple nodes

**For this task**: Use `ReadWriteOnce` with 1Mi storage.

### Step 5: Create Your YAML Files

Create two separate files:

**service.yaml** - Define your headless service
**statefulset.yaml** - Define your StatefulSet with volume claim templates

**Tips**:
- Use proper indentation (2 spaces in YAML)
- Ensure label selectors match exactly
- Reference the correct image with `imagePullPolicy: Never`
- Mount the volume to `/data` path

### Step 6: Deploy Your Resources

Deploy in this order:

```bash
# 1. Create the service first (required by StatefulSet)
kubectl apply -f service.yaml

# 2. Create the StatefulSet
kubectl apply -f statefulset.yaml

# 3. Watch the pods come up in sequence
kubectl get pods -n task-02 -w
```

**Expected behavior**:
- Pods are created sequentially: 0, then 1, then 2, then 3
- Each pod waits for the previous one to be Running before starting
- Each pod gets its own PVC: `data-key-value-svc-0`, `data-key-value-svc-1`, etc.

### Step 7: Verify Your Deployment

Check all resources:

```bash
# Check StatefulSet status
kubectl get statefulset -n task-02

# Check pods (should see 4 pods: -0, -1, -2, -3)
kubectl get pods -n task-02

# Check PVCs (should see 4 PVCs, one per pod)
kubectl get pvc -n task-02

# Check the headless service
kubectl get service -n task-02
```

**Success indicators**:
- StatefulSet shows 4/4 ready
- All 4 pods are in Running state
- 4 PVCs exist and are Bound
- Service shows ClusterIP: None

### Step 8: Test Your Application

Test data storage and retrieval:

```bash
# Test 1: Store data in pod-0
kubectl exec -n task-02 key-value-svc-0 -- \
  curl -X POST http://localhost:5000/obj/testkey -d "Hello World"

# Test 2: Retrieve data from pod-0
kubectl exec -n task-02 key-value-svc-0 -- \
  curl http://localhost:5000/obj/testkey

# Should return: Hello World
```

Test DNS resolution:

```bash
# Test pod-to-pod communication via DNS
kubectl run -it --rm test --image=busybox --restart=Never -n task-02 -- \
  nslookup key-value-svc-0.key-value-headless.task-02.svc.cluster.local
```

### Step 9: Test Data Persistence

This is the critical test - data must survive pod restarts:

```bash
# 1. Store important data
kubectl exec -n task-02 key-value-svc-0 -- \
  curl -X POST http://localhost:5000/obj/persistent-test -d "Important Data"

# 2. Delete the pod
kubectl delete pod key-value-svc-0 -n task-02

# 3. Wait for pod to recreate (StatefulSet controller does this automatically)
kubectl wait --for=condition=Ready pod/key-value-svc-0 -n task-02 --timeout=60s

# 4. Check if data still exists
kubectl exec -n task-02 key-value-svc-0 -- \
  curl http://localhost:5000/obj/persistent-test

# Should return: Important Data ✅
```

**Why does this work?**
- The PVC remains bound even when the pod is deleted
- When the StatefulSet recreates the pod, it reattaches the same PVC
- Your data in `/data` is preserved

## 🎓 Learning Resources

### Key Concepts

**StatefulSet vs Deployment**:
- **Deployment**: Pods are interchangeable, random names
- **StatefulSet**: Pods have identity, predictable names

**PersistentVolumeClaim (PVC)**:
- A request for storage by a pod
- Binds to a PersistentVolume (PV)
- Survives pod deletion

**Headless Service**:
- No cluster IP assigned
- Creates DNS records for each pod
- Used for direct pod-to-pod communication

### Common Pitfalls

❌ **Forgetting `imagePullPolicy: Never`**
- Result: Pod tries to pull from Docker Hub and fails

❌ **Mismatched labels**
- Result: Service can't find pods, selector doesn't match

❌ **Wrong service name in StatefulSet**
- Result: StatefulSet can't create pods, missing serviceName

❌ **Incorrect volumeMount name**
- Result: Volume not mounted, data not persistent

## 📊 Evaluation Criteria (100 points)

Your solution will be evaluated on:

| Criterion | Points | Check |
|-----------|--------|-------|
| **StatefulSet exists** | 15 | StatefulSet 'key-value-svc' created |
| **Replica count** | 10 | Exactly 4 replicas |
| **PVCs created** | 15 | 4 PVCs exist (one per pod) |
| **Headless service** | 10 | Service is headless and configured |
| **Pods running** | 10 | All 4 pods in Running state |
| **Store data** | 10 | POST /obj/key works |
| **Retrieve data** | 10 | GET /obj/key returns stored data |
| **Data persistence** | 20 | Data survives pod restart |

## 🚀 Request Evaluation

When you're ready:

```bash
~/student-tools/request-evaluation.sh task-02
```

Review your score. If satisfied:

```bash
~/student-tools/submit-final.sh task-02
```

## 🧹 Clean Up (Optional)

When finished experimenting:

```bash
# Delete the StatefulSet
kubectl delete statefulset key-value-svc -n task-02

# PVCs are NOT automatically deleted (by design)
# Delete them manually if you want to clean up
kubectl delete pvc -l app=key-value -n task-02
```

## 💡 Hints

<details>
<summary>Hint 1: StatefulSet serviceName field</summary>

The `serviceName` field in the StatefulSet spec must match your headless service name exactly. This is how Kubernetes knows which service to use for creating DNS records.

</details>

<details>
<summary>Hint 2: Volume mount name must match</summary>

The `volumeMounts[].name` in your container spec must match the `volumeClaimTemplates[].metadata.name`. This is how the volume gets connected to the container.

</details>

<details>
<summary>Hint 3: Testing data persistence</summary>

To properly test persistence:
1. Write data to a pod
2. Delete that specific pod (use pod-0 for simplicity)
3. Wait for StatefulSet to recreate it
4. Read the data back - it should still be there

The PVC stays bound to the same pod name when it recreates.

</details>

## 📚 Further Reading

- [Kubernetes StatefulSets Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)

Good luck! 🎓
