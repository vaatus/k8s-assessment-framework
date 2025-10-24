# Test Runner Pod

Lightweight Python container that runs inside student K3s clusters to perform application-level testing.

## Purpose

Lambda functions cannot directly access cluster-internal services. This test runner pod:
- Deploys temporarily into the student cluster
- Executes HTTP endpoint checks
- Tests data persistence
- Validates graceful shutdown behavior
- Returns results to Lambda

## Building

```bash
cd evaluation/test-runner
docker build -t test-runner:latest .
docker tag test-runner:latest <registry>/test-runner:latest
docker push <registry>/test-runner:latest
```

## Usage

The evaluator Lambda:
1. Creates a pod using this image
2. Passes test specification via stdin as JSON
3. Collects results from pod logs
4. Deletes the pod

## Test Specification Format

```json
{
  "checks": [
    {
      "check_id": "backend_ping",
      "check_type": "http_get",
      "service": "svc-backend",
      "namespace": "task-03",
      "port": 5000,
      "path": "/ping",
      "expected_status": 200,
      "timeout": 30
    }
  ]
}
```

## Supported Check Types

- `http_get`: HTTP GET request with status/body validation
- `http_post`: HTTP POST request with status validation
- `data_persistence`: Store data, restart pod, verify data exists (requires kubectl)
- `graceful_shutdown`: Verify cleanup on pod termination (requires kubectl)
