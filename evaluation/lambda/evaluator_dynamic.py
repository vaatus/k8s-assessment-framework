"""
Dynamic Kubernetes Assessment Evaluator
Supports multiple task types with resource validation and HTTP endpoint testing
Uses test-runner pod for cluster-internal HTTP checks
"""

import json
import boto3
import os
from datetime import datetime
import uuid
import requests
import urllib3
from urllib3.exceptions import InsecureRequestWarning
import yaml
import time
import base64

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'
TEST_RUNNER_IMAGE = os.environ.get('TEST_RUNNER_IMAGE', 'public.ecr.aws/your-registry/test-runner:latest')

urllib3.disable_warnings(InsecureRequestWarning)


def lambda_handler(event, context):
    """
    Main Lambda handler for dynamic task evaluation
    """
    try:
        # API Key validation
        api_key = os.environ.get('API_KEY')
        if api_key:
            headers = event.get('headers', {})
            request_api_key = headers.get('X-API-Key') or headers.get('x-api-key')
            if not request_api_key or request_api_key != api_key:
                return error_response(401, 'Unauthorized', 'Invalid or missing API key')

        # Parse request
        body = parse_request_body(event)
        student_id = body.get('student_id')
        task_id = body.get('task_id')
        cluster_endpoint = body.get('cluster_endpoint')
        cluster_token = body.get('cluster_token')

        if not all([student_id, task_id, cluster_endpoint, cluster_token]):
            return error_response(400, 'Missing required parameters',
                                'student_id, task_id, cluster_endpoint, cluster_token required')

        print(f"Evaluating: student={student_id}, task={task_id}")

        # Load task specification
        task_spec = load_task_spec(task_id)
        if not task_spec:
            return error_response(400, f'Task not found: {task_id}',
                                'Task specification could not be loaded')

        # Create Kubernetes API session
        session = create_k8s_session(cluster_endpoint, cluster_token)
        namespace = task_spec.get('namespace', task_id)

        # Test connectivity
        conn_test = test_cluster_connection(session, cluster_endpoint, namespace)
        if not conn_test['success']:
            return error_response(400, 'Cannot connect to cluster', conn_test['error'])

        # Run evaluation
        evaluator = TaskEvaluator(session, cluster_endpoint, cluster_token, namespace, task_spec)
        evaluation_results = evaluator.evaluate()
        score = evaluator.calculate_score(evaluation_results)

        # Generate report
        eval_token = str(uuid.uuid4())
        report = {
            'eval_token': eval_token,
            'student_id': student_id,
            'task_id': task_id,
            'timestamp': datetime.utcnow().isoformat(),
            'score': score,
            'max_score': task_spec.get('scoring', {}).get('max_score', 100),
            'results': evaluation_results,
            'status': 'completed'
        }

        # Store in S3
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=f'evaluations/{student_id}/{task_id}/{eval_token}.json',
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )

        print(f"Evaluation complete: {score}/{report['max_score']}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'eval_token': eval_token,
                'score': score,
                'max_score': report['max_score'],
                'message': 'Evaluation completed.',
                'results_summary': generate_summary(evaluation_results, task_spec)
            })
        }

    except Exception as e:
        print(f"Evaluation error: {e}")
        import traceback
        traceback.print_exc()
        return error_response(500, 'Internal error', str(e))


def load_task_spec(task_id):
    """Load task specification from S3 or use embedded spec"""
    try:
        response = s3.get_object(
            Bucket=BUCKET_NAME,
            Key=f'task-specs/{task_id}/task-spec.yaml'
        )
        return yaml.safe_load(response['Body'].read().decode('utf-8'))
    except s3.exceptions.NoSuchKey:
        print(f"Task spec not in S3, using embedded")
        return get_embedded_spec(task_id)
    except Exception as e:
        print(f"Error loading spec: {e}")
        return get_embedded_spec(task_id)


def get_embedded_spec(task_id):
    """Embedded specifications for backward compatibility"""
    if task_id == 'task-01':
        return {
            'task_id': 'task-01',
            'namespace': 'task-01',
            'required_resources': {
                'deployments': [{
                    'name': 'nginx-web',
                    'replicas': 2,
                    'selector_labels': {'app': 'nginx'},
                    'containers': [{
                        'image_pattern': 'nginx',
                        'resources': {'limits_required': True}
                    }]
                }]
            },
            'scoring': {
                'max_score': 100,
                'criteria': [
                    {'id': 'deployment_exists', 'points': 20},
                    {'id': 'replicas_correct', 'points': 15},
                    {'id': 'image_correct', 'points': 15},
                    {'id': 'resources_set', 'points': 20},
                    {'id': 'labels_correct', 'points': 10},
                    {'id': 'pod_count_correct', 'points': 10},
                    {'id': 'pods_running', 'points': 10}
                ]
            }
        }
    return None


def create_k8s_session(endpoint, token):
    """Create authenticated requests session for K8s API"""
    session = requests.Session()
    session.verify = False
    session.headers.update({
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    })
    return session


def test_cluster_connection(session, endpoint, namespace):
    """Test cluster connectivity"""
    try:
        response = session.get(f'{endpoint}/api/v1/namespaces/{namespace}', timeout=30)
        if response.status_code == 200:
            return {'success': True}
        elif response.status_code == 404:
            return {'success': False, 'error': f'Namespace {namespace} not found'}
        elif response.status_code == 401:
            return {'success': False, 'error': 'Authentication failed'}
        else:
            return {'success': False, 'error': f'API error: {response.status_code}'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


class TaskEvaluator:
    """Evaluates student tasks based on task specifications"""

    def __init__(self, session, endpoint, token, namespace, task_spec):
        self.session = session
        self.endpoint = endpoint
        self.token = token
        self.namespace = namespace
        self.task_spec = task_spec
        self.results = {}

    def evaluate(self):
        """Run complete evaluation"""
        print("Starting resource validation...")
        self.check_deployments()
        self.check_statefulsets()
        self.check_services()
        self.check_pvcs()
        self.check_pods()
        self.check_probes()

        # Run application checks if defined
        if self.task_spec.get('application_checks'):
            print("Starting application checks...")
            self.run_application_checks()

        # Run custom checks if defined
        if self.task_spec.get('custom_checks'):
            print("Starting custom checks...")
            self.run_custom_checks()

        return self.results

    def check_deployments(self):
        """Validate deployments"""
        deployments = self.task_spec.get('required_resources', {}).get('deployments', [])

        for spec in deployments:
            name = spec['name']
            prefix = f"deployment_{name}"

            try:
                resp = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/deployments/{name}',
                    timeout=30
                )

                if resp.status_code == 200:
                    self.results[f'{prefix}_exists'] = True
                    deploy = resp.json()

                    # Replicas
                    if 'replicas' in spec:
                        actual = deploy.get('spec', {}).get('replicas', 0)
                        self.results[f'{prefix}_replicas_correct'] = (actual == spec['replicas'])

                    # Image
                    containers = deploy.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
                    if containers and spec.get('containers'):
                        image = containers[0].get('image', '')
                        pattern = spec['containers'][0].get('image_pattern', '')
                        self.results[f'{prefix}_image_correct'] = (pattern.lower() in image.lower())

                        # Resources
                        if spec['containers'][0].get('resources', {}).get('limits_required'):
                            limits = containers[0].get('resources', {}).get('limits', {})
                            self.results[f'{prefix}_resources_set'] = ('cpu' in limits and 'memory' in limits)

                    # Labels (pod template)
                    if 'selector_labels' in spec:
                        pod_labels = deploy.get('spec', {}).get('template', {}).get('metadata', {}).get('labels', {})
                        match = all(pod_labels.get(k) == v for k, v in spec['selector_labels'].items())
                        self.results[f'{prefix}_labels_correct'] = match

                    # Probes
                    if spec.get('startup_probe', {}).get('required'):
                        probe = containers[0].get('startupProbe') if containers else None
                        self.results[f'{prefix}_startup_probe_configured'] = (probe is not None)

                    if spec.get('liveness_probe', {}).get('required'):
                        probe = containers[0].get('livenessProbe') if containers else None
                        self.results[f'{prefix}_liveness_probe_configured'] = (probe is not None)

                else:
                    self.results[f'{prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking deployment {name}: {e}")
                self.results[f'{prefix}_exists'] = False

    def check_statefulsets(self):
        """Validate statefulsets"""
        statefulsets = self.task_spec.get('required_resources', {}).get('statefulsets', [])

        for spec in statefulsets:
            name = spec['name']
            prefix = f"statefulset_{name}"

            try:
                resp = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/statefulsets/{name}',
                    timeout=30
                )

                if resp.status_code == 200:
                    self.results[f'{prefix}_exists'] = True
                    sts = resp.json()

                    # Replicas
                    if 'replicas' in spec:
                        actual = sts.get('spec', {}).get('replicas', 0)
                        self.results[f'{prefix}_replicas_correct'] = (actual == spec['replicas'])

                    # Volume claim templates
                    if 'volumeClaimTemplates' in spec:
                        vct = sts.get('spec', {}).get('volumeClaimTemplates', [])
                        self.results[f'{prefix}_has_volume_claims'] = (len(vct) > 0)
                else:
                    self.results[f'{prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking statefulset {name}: {e}")
                self.results[f'{prefix}_exists'] = False

    def check_services(self):
        """Validate services"""
        services = self.task_spec.get('required_resources', {}).get('services', [])

        for spec in services:
            name = spec['name']
            prefix = f"service_{name}"

            try:
                resp = self.session.get(
                    f'{self.endpoint}/api/v1/namespaces/{self.namespace}/services/{name}',
                    timeout=30
                )

                if resp.status_code == 200:
                    self.results[f'{prefix}_exists'] = True
                    svc = resp.json()

                    # Type
                    if 'type' in spec:
                        svc_type = svc.get('spec', {}).get('type', 'ClusterIP')
                        self.results[f'{prefix}_type_correct'] = (svc_type == spec['type'])

                    # Headless
                    if spec.get('clusterIP') == 'None':
                        cluster_ip = svc.get('spec', {}).get('clusterIP')
                        self.results[f'{prefix}_is_headless'] = (cluster_ip == 'None')
                else:
                    self.results[f'{prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking service {name}: {e}")
                self.results[f'{prefix}_exists'] = False

    def check_pvcs(self):
        """Validate persistent volume claims"""
        statefulsets = self.task_spec.get('required_resources', {}).get('statefulsets', [])

        for spec in statefulsets:
            if 'volumeClaimTemplates' in spec:
                name = spec['name']
                replicas = spec.get('replicas', 1)

                try:
                    resp = self.session.get(
                        f'{self.endpoint}/api/v1/namespaces/{self.namespace}/persistentvolumeclaims',
                        timeout=30
                    )

                    if resp.status_code == 200:
                        pvcs = resp.json().get('items', [])
                        sts_pvcs = [p for p in pvcs if name in p['metadata']['name']]
                        self.results[f'statefulset_{name}_pvcs_created'] = (len(sts_pvcs) >= replicas)

                except Exception as e:
                    print(f"Error checking PVCs for {name}: {e}")

    def check_pods(self):
        """Validate pod status and count"""
        try:
            resp = self.session.get(
                f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods',
                timeout=30
            )

            if resp.status_code != 200:
                return

            pods = resp.json().get('items', [])

            # Check deployment pods
            for spec in self.task_spec.get('required_resources', {}).get('deployments', []):
                name = spec['name']
                labels = spec.get('selector_labels', {})
                expected = spec.get('replicas', 1)

                matching = [p for p in pods if all(
                    p.get('metadata', {}).get('labels', {}).get(k) == v
                    for k, v in labels.items()
                )]

                self.results[f'deployment_{name}_pod_count_correct'] = (len(matching) == expected)

                running = sum(1 for p in matching if p.get('status', {}).get('phase') == 'Running')
                self.results[f'deployment_{name}_pods_running'] = (running == expected)

            # Check statefulset pods
            for spec in self.task_spec.get('required_resources', {}).get('statefulsets', []):
                name = spec['name']
                labels = spec.get('selector_labels', {})
                expected = spec.get('replicas', 1)

                matching = [p for p in pods if all(
                    p.get('metadata', {}).get('labels', {}).get(k) == v
                    for k, v in labels.items()
                )]

                self.results[f'statefulset_{name}_pod_count_correct'] = (len(matching) == expected)

                running = sum(1 for p in matching if p.get('status', {}).get('phase') == 'Running')
                self.results[f'statefulset_{name}_pods_running'] = (running == expected)

        except Exception as e:
            print(f"Error checking pods: {e}")

    def check_probes(self):
        """Validate probe configuration"""
        probe_checks = self.task_spec.get('probe_checks', [])

        for check in probe_checks:
            check_id = check['check_id']
            deploy_name = check.get('deployment')
            probe_type = check.get('probe_type')

            try:
                resp = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/deployments/{deploy_name}',
                    timeout=30
                )

                if resp.status_code == 200:
                    deploy = resp.json()
                    containers = deploy.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])

                    if containers:
                        probe_key = f'{probe_type}Probe'
                        probe = containers[0].get(probe_key)

                        if probe:
                            http_get = probe.get('httpGet', {})
                            path_ok = True
                            if 'path' in check:
                                path_ok = (http_get.get('path') == check['path'])

                            period_ok = True
                            if 'period_seconds' in check:
                                period_ok = (probe.get('periodSeconds') == check['period_seconds'])

                            failure_ok = True
                            if 'failure_threshold' in check:
                                failure_ok = (probe.get('failureThreshold') == check['failure_threshold'])

                            self.results[check_id] = (path_ok and period_ok and failure_ok)
                        else:
                            self.results[check_id] = False
                    else:
                        self.results[check_id] = False
                else:
                    self.results[check_id] = False

            except Exception as e:
                print(f"Error checking probe {check_id}: {e}")
                self.results[check_id] = False

    def run_application_checks(self):
        """Run HTTP checks using test-runner pod"""
        app_checks = self.task_spec.get('application_checks', [])
        if not app_checks:
            return

        # Add namespace to each check
        for check in app_checks:
            check['namespace'] = self.namespace

        # Deploy test-runner pod
        pod_name = f'test-runner-{uuid.uuid4().hex[:8]}'
        test_spec = {'checks': app_checks}

        try:
            print(f"Deploying test-runner pod: {pod_name}")
            self.create_test_runner_pod(pod_name, test_spec)

            # Wait for pod to complete
            print("Waiting for test-runner to complete...")
            self.wait_for_pod_completion(pod_name, timeout=60)

            # Get pod logs (contains test results)
            logs = self.get_pod_logs(pod_name)
            print(f"Test-runner logs length: {len(logs)} bytes")
            print("=== FULL TEST-RUNNER OUTPUT ===")
            print(logs)
            print("=== END TEST-RUNNER OUTPUT ===")

            # Parse results from logs
            test_results = self.parse_test_results(logs)
            print(f"Parsed {len(test_results)} test results")

            # Merge results
            for check_id, result in test_results.items():
                self.results[check_id] = result.get('passed', False)
                print(f"  {check_id}: {result.get('passed', False)}")

        except Exception as e:
            print(f"Error running application checks: {e}")
            import traceback
            traceback.print_exc()
            # Mark all app checks as failed
            for check in app_checks:
                self.results[check['check_id']] = False

        finally:
            # Clean up test-runner pod
            try:
                self.delete_test_runner_pod(pod_name)
            except:
                pass

    def run_custom_checks(self):
        """Run custom checks defined in task spec"""
        custom_checks = self.task_spec.get('custom_checks', [])

        for check in custom_checks:
            check_id = check['check_id']
            print(f"Running custom check: {check_id}")

            # Handle graceful_shutdown check
            if check_id == 'graceful_shutdown':
                self.results[check_id] = self.check_graceful_shutdown(check)
            else:
                # Future custom checks can be added here
                print(f"Warning: Unknown custom check type: {check_id}")
                self.results[check_id] = False

    def check_graceful_shutdown(self, check):
        """Test graceful shutdown by checking if frontend calls backend /game-over on termination"""
        try:
            print("Testing graceful shutdown...")

            # Step 1: Get backend pod name
            backend_pod = self.get_pod_by_label('app', 'backend')
            if not backend_pod:
                print("Error: Backend pod not found")
                return False

            backend_pod_name = backend_pod['metadata']['name']
            print(f"Backend pod: {backend_pod_name}")

            # Step 2: Get initial backend logs to check if /game-over was already called
            initial_logs = self.get_pod_logs(backend_pod_name)
            initial_game_over_count = initial_logs.count('POST /game-over')
            print(f"Initial /game-over calls: {initial_game_over_count}")

            # Step 3: Get frontend pod name
            frontend_pod = self.get_pod_by_label('app', 'frontend')
            if not frontend_pod:
                print("Error: Frontend pod not found")
                return False

            frontend_pod_name = frontend_pod['metadata']['name']
            print(f"Frontend pod: {frontend_pod_name}")

            # Step 4: Delete frontend pod to trigger preStop hook
            print(f"Deleting frontend pod to trigger preStop hook...")
            self.delete_pod(frontend_pod_name)

            # Step 5: Wait for termination and new pod to come up
            print("Waiting for pod termination and restart...")
            time.sleep(15)  # Give time for preStop hook to execute and pod to restart

            # Step 6: Check backend logs again
            final_logs = self.get_pod_logs(backend_pod_name)
            final_game_over_count = final_logs.count('POST /game-over')
            print(f"Final /game-over calls: {final_game_over_count}")

            # Step 7: Verify that /game-over was called
            if final_game_over_count > initial_game_over_count:
                print("✓ Graceful shutdown working: /game-over was called")
                return True
            else:
                print("✗ Graceful shutdown failed: /game-over was not called")
                return False

        except Exception as e:
            print(f"Error testing graceful shutdown: {e}")
            import traceback
            traceback.print_exc()
            return False

    def get_pod_by_label(self, label_key, label_value):
        """Get first pod matching label selector"""
        try:
            resp = self.session.get(
                f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods',
                params={'labelSelector': f'{label_key}={label_value}'},
                timeout=30
            )

            if resp.status_code == 200:
                pods = resp.json().get('items', [])
                if pods:
                    return pods[0]
            return None
        except Exception as e:
            print(f"Error getting pod by label {label_key}={label_value}: {e}")
            return None

    def delete_pod(self, pod_name):
        """Delete a pod"""
        resp = self.session.delete(
            f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods/{pod_name}',
            timeout=30
        )
        return resp.status_code in [200, 202]

    def wait_for_pod_completion(self, pod_name, timeout=60):
        """Wait for pod to complete (Succeeded or Failed status)"""
        for i in range(timeout):
            time.sleep(1)
            try:
                resp = self.session.get(
                    f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods/{pod_name}',
                    timeout=10
                )
                if resp.status_code == 200:
                    pod = resp.json()
                    phase = pod.get('status', {}).get('phase')
                    if phase == 'Succeeded':
                        print(f"Pod {pod_name} completed successfully")
                        return True
                    elif phase == 'Failed':
                        print(f"Pod {pod_name} failed")
                        return False
            except Exception as e:
                print(f"Error checking pod status: {e}")

        print(f"Pod {pod_name} did not complete within {timeout}s")
        return False

    def create_test_runner_pod(self, pod_name, test_spec):
        """Create test-runner pod in student cluster"""
        pod_manifest = {
            'apiVersion': 'v1',
            'kind': 'Pod',
            'metadata': {
                'name': pod_name,
                'namespace': self.namespace
            },
            'spec': {
                'restartPolicy': 'Never',
                'containers': [{
                    'name': 'test-runner',
                    'image': TEST_RUNNER_IMAGE,
                    'imagePullPolicy': 'Never',  # Use local image, don't pull from registry
                    'stdin': True,
                    'stdinOnce': True,
                    'command': ['python3', '/app/test_runner.py'],
                    'env': [{
                        'name': 'TEST_SPEC',
                        'value': json.dumps(test_spec)
                    }]
                }]
            }
        }

        resp = self.session.post(
            f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods',
            json=pod_manifest,
            timeout=30
        )

        if resp.status_code not in [200, 201]:
            raise Exception(f"Failed to create test-runner pod: {resp.status_code} {resp.text}")

        # Wait for pod to be ready
        for _ in range(30):  # 30 second timeout
            time.sleep(1)
            resp = self.session.get(
                f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods/{pod_name}',
                timeout=10
            )
            if resp.status_code == 200:
                pod = resp.json()
                phase = pod.get('status', {}).get('phase')
                if phase in ['Succeeded', 'Failed', 'Running']:
                    break

    def get_pod_logs(self, pod_name):
        """Get logs from test-runner pod"""
        resp = self.session.get(
            f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods/{pod_name}/log',
            timeout=30
        )

        if resp.status_code == 200:
            return resp.text
        else:
            raise Exception(f"Failed to get pod logs: {resp.status_code}")

    def delete_test_runner_pod(self, pod_name):
        """Delete test-runner pod"""
        self.session.delete(
            f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods/{pod_name}',
            timeout=30
        )

    def parse_test_results(self, logs):
        """Parse JSON results from test-runner logs"""
        try:
            # Look for JSON in logs
            for line in logs.split('\n'):
                line = line.strip()
                if line.startswith('{'):
                    try:
                        data = json.loads(line)
                        if 'results' in data:
                            print(f"Found results in JSON: {list(data['results'].keys())}")
                            return data['results']
                    except json.JSONDecodeError as e:
                        print(f"Failed to parse JSON line: {e}")
                        continue

            print("No valid JSON with 'results' key found in logs")
            print(f"Log sample: {logs[:500]}")
            return {}
        except Exception as e:
            print(f"Error parsing test results: {e}")
            return {}

    def calculate_score(self, results):
        """Calculate score based on criteria"""
        criteria = self.task_spec.get('scoring', {}).get('criteria', [])
        score = 0

        # Debug: Print all result keys
        print(f"DEBUG: All result keys: {list(results.keys())}")

        for criterion in criteria:
            criterion_id = criterion['id']
            points = criterion['points']

            # Find matching result
            passed = self.find_result(results, criterion_id)

            if passed:
                score += points
                print(f"✓ {criterion_id}: +{points}")
            else:
                print(f"✗ {criterion_id}: 0")

        return score

    def find_result(self, results, criterion_id):
        """Find result value for criterion"""
        # First try exact match
        if criterion_id in results:
            return results[criterion_id]

        # Case 1: criterion_id has resource prefix (e.g., "deployment_exists")
        # Match against "deployment_nginx-web_exists"
        parts = criterion_id.split('_', 1)
        if len(parts) == 2:
            resource_type, check_name = parts
            for key, value in results.items():
                if key.startswith(f"{resource_type}_") and key.endswith(f"_{check_name}") and value:
                    return True

        # Case 2: criterion_id has NO prefix (e.g., "replicas_correct")
        # Match against any key ending with "_replicas_correct"
        for key, value in results.items():
            if key.endswith(f"_{criterion_id}") and value:
                return True

        return False


def generate_summary(results, task_spec):
    """Generate results summary"""
    summary = {}
    criteria = task_spec.get('scoring', {}).get('criteria', [])

    for criterion in criteria:
        cid = criterion['id']
        found = False

        # First check exact match
        if cid in results:
            summary[cid] = results[cid]
            found = True
        else:
            # Case 1: criterion has resource prefix (e.g., "deployment_exists")
            parts = cid.split('_', 1)
            if len(parts) == 2:
                resource_type, check_name = parts
                for key, value in results.items():
                    if key.startswith(f"{resource_type}_") and key.endswith(f"_{check_name}"):
                        summary[cid] = value
                        found = True
                        break

            # Case 2: criterion has NO prefix (e.g., "replicas_correct")
            if not found:
                for key, value in results.items():
                    if key.endswith(f"_{cid}"):
                        summary[cid] = value
                        found = True
                        break

        if not found:
            summary[cid] = False

    return summary


def parse_request_body(event):
    """Parse request body from event"""
    if 'body' in event:
        if isinstance(event['body'], str):
            return json.loads(event['body'])
        return event['body']
    return event


def error_response(status_code, error, details):
    """Generate error response"""
    return {
        'statusCode': status_code,
        'body': json.dumps({
            'error': error,
            'details': details
        })
    }
