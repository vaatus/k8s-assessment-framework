# Task 01: Deploy NGINX Web Application

## Objective
Deploy a scalable NGINX web application with specific resource requirements and configuration.

## Requirements

### Deployment Specifications
- **Name**: `nginx-web`
- **Namespace**: `task-01`
- **Image**: `nginx:1.25`
- **Replicas**: 3
- **Labels**: `app=nginx-web`

### Resource Requirements
- **CPU Limit**: 100m
- **Memory Limit**: 128Mi
- **CPU Request**: 50m
- **Memory Request**: 64Mi

### Additional Configuration
- Container port: 80
- Deployment strategy: RollingUpdate
- All pods must be in Running state

## Evaluation Criteria
Your deployment will be evaluated on:
1. ✅ Deployment exists (20 points)
2. ✅ Correct number of replicas (15 points)
3. ✅ Correct container image (15 points)
4. ✅ Resource limits and requests set (20 points)
5. ✅ Correct labels applied (10 points)
6. ✅ Correct pod count (10 points)
7. ✅ All pods running successfully (10 points)

**Total: 100 points**

## Getting Started

1. Create the namespace:
   ```bash
   kubectl create namespace task-01
   ```

2. Create your deployment manifest and apply it

3. Verify your deployment:
   ```bash
   kubectl get deployment nginx-web -n task-01
   kubectl get pods -n task-01 -l app=nginx-web
   ```

4. When ready, request evaluation using the provided scripts

## Submission Process

1. Complete the task requirements
2. Run evaluation: `./request-evaluation.sh task-01`
3. Review the results
4. If satisfied, submit: `./submit-final.sh task-01`

**Note**: You can run evaluation multiple times, but only submit once when you're confident in your solution.