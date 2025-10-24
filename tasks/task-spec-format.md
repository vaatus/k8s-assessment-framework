# Task Specification Format

This document defines the format for task specifications used by the evaluation system.

## Overview

Each task is defined by a JSON/YAML specification file that tells the evaluator:
- What Kubernetes resources to expect
- How to validate them
- What application-level checks to perform
- How to calculate the score

## Task Specification Schema

```yaml
task_id: "task-01"
task_name: "NGINX Web Deployment"
task_type: "deployment"  # deployment, statefulset, daemonset, custom
namespace: "task-01"     # Task-specific namespace

# Task description (shown to students)
description: |
  Deploy an NGINX web server with 2 replicas, proper labels, and resource limits.

# Required Kubernetes resources
required_resources:
  deployments:
    - name: "nginx-web"
      replicas: 2
      selector_labels:
        app: "nginx"
      containers:
        - name: "nginx"
          image_pattern: "nginx"  # Regex or substring match
          ports:
            - containerPort: 80
          resources:
            limits_required: true  # Must have CPU and memory limits

  services:
    - name: "nginx-service"
      type: "NodePort"  # Optional: ClusterIP, NodePort, LoadBalancer
      selector_labels:
        app: "nginx"
      ports:
        - port: 80
          targetPort: 80

# Pod-level checks
pod_checks:
  - check_type: "pod_count"
    expected: 2
    points: 10

  - check_type: "pod_status"
    expected: "Running"
    points: 10

  - check_type: "pod_labels"
    expected:
      app: "nginx"
    points: 10

# Application-level checks (HTTP endpoints, etc.)
application_checks:
  - check_type: "http_get"
    service: "nginx-service"
    path: "/"
    expected_status: 200
    timeout: 30
    points: 10
    description: "Service responds to HTTP requests"

# Custom validation logic (optional)
custom_checks:
  - check_id: "persistent_data"
    check_type: "custom_script"
    script: |
      # Custom Python code to validate
      # Returns: (passed: bool, message: str, points: int)
    points: 20

# Scoring configuration
scoring:
  max_score: 100
  passing_score: 70
  criteria:
    - id: "deployment_exists"
      points: 20
      required: true  # Must pass for other checks to run
    - id: "replicas_correct"
      points: 15
    - id: "image_correct"
      points: 15
    - id: "resources_set"
      points: 20
    - id: "labels_correct"
      points: 10
    - id: "pod_count_correct"
      points: 10
    - id: "pods_running"
      points: 10

# Task-specific configuration
task_config:
  init_script_url: ""  # Optional: URL to download init script
  workspace_files: []  # Files to create in student workspace
  required_tools: []   # Tools needed (docker, kubectl, etc.)
```

## Task Types

### 1. Simple Deployment Task (task-01)

Current NGINX task - just Kubernetes resource validation.

### 2. StatefulSet Task (task-02)

Requires:
- StatefulSet with N replicas
- PersistentVolumeClaims
- Headless service
- Data persistence validation

### 3. Application-Level Task (task-03)

Requires:
- Custom application with endpoints
- Liveness/readiness/startup probes
- HTTP endpoint validation
- Graceful shutdown testing

### 4. Custom Task (task-04+)

Fully custom validation logic with Python script.

## Evaluation Flow

```
1. Read task specification from S3 or embedded in evaluator
2. Connect to student K3s cluster
3. Check namespace exists
4. Validate required Kubernetes resources:
   - Deployments/StatefulSets exist with correct spec
   - Services exist with correct configuration
   - PVCs exist if required
5. Check pod status and count
6. Perform application-level checks:
   - HTTP endpoint testing
   - Data persistence testing
   - Graceful shutdown testing
7. Run custom validation scripts if defined
8. Calculate score based on criteria
9. Return detailed results with breakdown
```

## Example: task-01 (Current NGINX Task)

```yaml
task_id: "task-01"
task_name: "NGINX Web Deployment"
task_type: "deployment"
namespace: "task-01"

required_resources:
  deployments:
    - name: "nginx-web"
      replicas: 2
      selector_labels:
        app: "nginx"
      containers:
        - name: "nginx"
          image_pattern: "nginx"
          ports:
            - containerPort: 80
          resources:
            limits_required: true

scoring:
  max_score: 100
  criteria:
    - id: "deployment_exists"
      points: 20
    - id: "replicas_correct"
      points: 15
    - id: "image_correct"
      points: 15
    - id: "resources_set"
      points: 20
    - id: "labels_correct"
      points: 10
    - id: "pod_count_correct"
      points: 10
    - id: "pods_running"
      points: 10
```

## Example: task-02 (StatefulSet)

```yaml
task_id: "task-02"
task_name: "StatefulSet Key-Value Store"
task_type: "statefulset"
namespace: "task-02"

required_resources:
  statefulsets:
    - name: "key-value-svc"
      replicas: 4
      selector_labels:
        app: "key-value"
      volumeClaimTemplates:
        - name: "data"
          storage: "1Mi"

  services:
    - name: "key-value-headless"
      type: "ClusterIP"
      clusterIP: "None"  # Headless service

application_checks:
  - check_type: "http_post"
    service: "key-value-svc-0.key-value-headless"
    path: "/obj/test"
    body: "testvalue"
    expected_status: 200
    points: 15

  - check_type: "http_get"
    service: "key-value-svc-0.key-value-headless"
    path: "/obj/test"
    expected_body: "testvalue"
    points: 15
    description: "Data persists in key-value store"

custom_checks:
  - check_id: "data_persistence_after_restart"
    points: 20
    description: "Data survives pod restart"
    script: |
      # Store data, delete pod, check data still exists

scoring:
  max_score: 100
  criteria:
    - id: "statefulset_exists"
      points: 20
    - id: "replica_count_correct"
      points: 10
    - id: "pvcs_created"
      points: 20
    - id: "headless_service_exists"
      points: 10
    - id: "data_storage_works"
      points: 15
    - id: "data_retrieval_works"
      points: 15
    - id: "data_persists_after_restart"
      points: 20
```

## Implementation Plan

1. **Create task specification files** for each task
2. **Update evaluator Lambda** to:
   - Load task specification (from S3 or embedded)
   - Dynamically validate based on spec
   - Support different resource types
   - Perform HTTP checks
   - Execute custom validation
3. **Store task specs in S3**: `k8s-eval-results/task-specs/{task_id}.yaml`
4. **CloudFormation passes task_id** to student, evaluator loads corresponding spec

This makes the system **highly extensible** - add new tasks by just creating a specification file!
