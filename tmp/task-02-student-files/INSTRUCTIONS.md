# Task-02 Complete Testing Instructions

Copy these files to your student EC2 instance and follow the steps below.

## Step 1: Build the Application

```bash
# Create app directory
mkdir -p ~/task02-app
cd ~/task02-app

# Copy the files (app.py and Dockerfile should be here)
# Then build:
docker build -t key-value-store:latest .
docker save key-value-store:latest | sudo k3s ctr images import -
echo "✅ Application built and imported!"
```

## Step 2: Deploy the Solution

```bash
# Copy solution.yaml to the task workspace
cp solution.yaml ~/k8s-workspace/tasks/task-02/solution.yaml

# Apply the solution
kubectl apply -f ~/k8s-workspace/tasks/task-02/solution.yaml

# Wait for pods
kubectl wait --for=condition=Ready pod -l app=key-value -n task-02 --timeout=120s

# Verify
kubectl get all,pvc -n task-02
```

## Step 3: Test the Application

```bash
# Store data
kubectl exec -n task-02 key-value-svc-0 -- curl -X POST http://localhost:5000/obj/testkey -d "testvalue"

# Retrieve data
kubectl exec -n task-02 key-value-svc-0 -- curl http://localhost:5000/obj/testkey
# Should output: testvalue
```

## Step 4: Request Evaluation

```bash
~/student-tools/request-evaluation.sh task-02
```

Expected: High score with all resource checks and HTTP checks passing!
