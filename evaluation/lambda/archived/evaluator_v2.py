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

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'
TASK_SPECS_BUCKET = 'k8s-eval-results'  # Store task specs here
TASK_SPECS_PREFIX = 'task-specs'

# Disable SSL warnings for self-signed K3s certificates
urllib3.disable_warnings(InsecureRequestWarning)


def lambda_handler(event, context):
    """
    Dynamic evaluation Lambda that supports multiple task types
    Receives: student_id, task_id, cluster_endpoint, cluster_token
    Returns: evaluation_token, score, detailed results
    """

    try:
        # Validate API Key
        api_key = os.environ.get('API_KEY')
        if api_key:
            headers = event.get('headers', {})
            request_api_key = headers.get('X-API-Key') or headers.get('x-api-key')

            if not request_api_key or request_api_key != api_key:
                return {
                    'statusCode': 401,
                    'body': json.dumps({
                        'error': 'Unauthorized',
                        'message': 'Invalid or missing API key'
                    })
                }

        # Parse request
        if 'body' in event:
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event

        student_id = body.get('student_id')
        task_id = body.get('task_id')
        cluster_endpoint = body.get('cluster_endpoint')
        cluster_token = body.get('cluster_token')

        # Validate inputs
        if not all([student_id, task_id, cluster_endpoint, cluster_token]):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required parameters: student_id, task_id, cluster_endpoint, cluster_token'
                })
            }

        print(f"Starting evaluation for student: {student_id}, task: {task_id}")

        # Load task specification
        task_spec = load_task_spec(task_id)
        if not task_spec:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': f'Task specification not found for task: {task_id}'
                })
            }

        # Create Kubernetes API session
        session = create_k8s_session(cluster_endpoint, cluster_token)
        namespace = task_spec.get('namespace', task_id)

        # Test cluster connection
        connectivity_test = test_cluster_connection(session, cluster_endpoint, namespace)
        if not connectivity_test['success']:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Cannot connect to student cluster',
                    'details': connectivity_test['error']
                })
            }

        # Run evaluation based on task specification
        evaluator = DynamicEvaluator(session, cluster_endpoint, namespace, task_spec)
        evaluation_results = evaluator.evaluate()

        # Calculate score
        score = evaluator.calculate_score(evaluation_results)

        # Generate eval token and report
        eval_token = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()

        report = {
            'eval_token': eval_token,
            'student_id': student_id,
            'task_id': task_id,
            'timestamp': timestamp,
            'score': score,
            'max_score': task_spec.get('scoring', {}).get('max_score', 100),
            'results': evaluation_results,
            'status': 'completed'
        }

        # Store results in S3
        result_key = f'evaluations/{student_id}/{task_id}/{eval_token}.json'
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=result_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )

        print(f"Evaluation completed. Score: {score}/{task_spec.get('scoring', {}).get('max_score', 100)}")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'eval_token': eval_token,
                'score': score,
                'max_score': task_spec.get('scoring', {}).get('max_score', 100),
                'message': 'Evaluation completed. Review results and submit if satisfied.',
                'results_summary': generate_results_summary(evaluation_results, task_spec)
            })
        }

    except Exception as e:
        print(f"Error during evaluation: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal evaluation error',
                'details': str(e)
            })
        }


def load_task_spec(task_id):
    """
    Load task specification from S3 or fallback to embedded specs
    """
    try:
        # Try loading from S3
        spec_key = f'{TASK_SPECS_PREFIX}/{task_id}/task-spec.yaml'
        response = s3.get_object(Bucket=TASK_SPECS_BUCKET, Key=spec_key)
        spec_content = response['Body'].read().decode('utf-8')
        return yaml.safe_load(spec_content)
    except s3.exceptions.NoSuchKey:
        print(f"Task spec not found in S3: {spec_key}, using embedded spec")
        # Fallback to embedded specs for backward compatibility
        return get_embedded_task_spec(task_id)
    except Exception as e:
        print(f"Error loading task spec: {e}")
        return get_embedded_task_spec(task_id)


def get_embedded_task_spec(task_id):
    """
    Embedded task specifications for backward compatibility
    """
    specs = {
        'task-01': {
            'task_id': 'task-01',
            'task_name': 'NGINX Web Deployment',
            'task_type': 'deployment',
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
    }
    return specs.get(task_id)


def create_k8s_session(endpoint, token):
    """
    Create requests session for Kubernetes API access
    """
    session = requests.Session()
    session.verify = False
    session.headers.update({
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    })
    return session


def test_cluster_connection(session, endpoint, namespace):
    """
    Test connection to student cluster
    """
    try:
        response = session.get(
            f'{endpoint}/api/v1/namespaces/{namespace}',
            timeout=30
        )

        if response.status_code == 200:
            return {'success': True}
        elif response.status_code == 404:
            return {
                'success': False,
                'error': f'Namespace {namespace} not found'
            }
        elif response.status_code == 401:
            return {
                'success': False,
                'error': 'Authentication failed - invalid token'
            }
        else:
            return {
                'success': False,
                'error': f'API request failed: {response.status_code} {response.text}'
            }
    except Exception as e:
        return {'success': False, 'error': str(e)}


class DynamicEvaluator:
    """
    Dynamic evaluator that processes tasks based on task specifications
    """

    def __init__(self, session, endpoint, namespace, task_spec):
        self.session = session
        self.endpoint = endpoint
        self.namespace = namespace
        self.task_spec = task_spec
        self.results = {}

    def evaluate(self):
        """
        Run complete evaluation based on task specification
        """
        print(f"Evaluating task: {self.task_spec.get('task_id')}")

        # Check required resources
        self.check_deployments()
        self.check_statefulsets()
        self.check_services()
        self.check_pvcs()
        self.check_pods()

        # Run application-level checks
        self.run_application_checks()

        # Run probe checks
        self.run_probe_checks()

        # Run custom checks
        self.run_custom_checks()

        return self.results

    def check_deployments(self):
        """
        Check deployments defined in task spec
        """
        deployments = self.task_spec.get('required_resources', {}).get('deployments', [])

        for deploy_spec in deployments:
            name = deploy_spec['name']
            result_prefix = f"deployment_{name}"

            try:
                response = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/deployments/{name}',
                    timeout=30
                )

                if response.status_code == 200:
                    self.results[f'{result_prefix}_exists'] = True
                    deployment = response.json()

                    # Check replicas
                    if 'replicas' in deploy_spec:
                        desired = deployment.get('spec', {}).get('replicas', 0)
                        self.results[f'{result_prefix}_replicas_correct'] = (desired == deploy_spec['replicas'])

                    # Check image
                    containers = deployment.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
                    if containers and deploy_spec.get('containers'):
                        image = containers[0].get('image', '')
                        image_pattern = deploy_spec['containers'][0].get('image_pattern', '')
                        self.results[f'{result_prefix}_image_correct'] = (image_pattern.lower() in image.lower())

                        # Check resources
                        if deploy_spec['containers'][0].get('resources', {}).get('limits_required'):
                            resources = containers[0].get('resources', {})
                            limits = resources.get('limits', {})
                            self.results[f'{result_prefix}_resources_set'] = ('cpu' in limits and 'memory' in limits)

                    # Check labels
                    if 'selector_labels' in deploy_spec:
                        pod_labels = deployment.get('spec', {}).get('template', {}).get('metadata', {}).get('labels', {})
                        labels_match = all(
                            pod_labels.get(k) == v
                            for k, v in deploy_spec['selector_labels'].items()
                        )
                        self.results[f'{result_prefix}_labels_correct'] = labels_match
                else:
                    self.results[f'{result_prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking deployment {name}: {e}")
                self.results[f'{result_prefix}_exists'] = False

    def check_statefulsets(self):
        """
        Check statefulsets defined in task spec
        """
        statefulsets = self.task_spec.get('required_resources', {}).get('statefulsets', [])

        for sts_spec in statefulsets:
            name = sts_spec['name']
            result_prefix = f"statefulset_{name}"

            try:
                response = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/statefulsets/{name}',
                    timeout=30
                )

                if response.status_code == 200:
                    self.results[f'{result_prefix}_exists'] = True
                    sts = response.json()

                    # Check replicas
                    if 'replicas' in sts_spec:
                        desired = sts.get('spec', {}).get('replicas', 0)
                        self.results[f'{result_prefix}_replicas_correct'] = (desired == sts_spec['replicas'])

                    # Check volumeClaimTemplates
                    if 'volumeClaimTemplates' in sts_spec:
                        vct = sts.get('spec', {}).get('volumeClaimTemplates', [])
                        self.results[f'{result_prefix}_has_volume_claims'] = len(vct) > 0
                else:
                    self.results[f'{result_prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking statefulset {name}: {e}")
                self.results[f'{result_prefix}_exists'] = False

    def check_services(self):
        """
        Check services defined in task spec
        """
        services = self.task_spec.get('required_resources', {}).get('services', [])

        for svc_spec in services:
            name = svc_spec['name']
            result_prefix = f"service_{name}"

            try:
                response = self.session.get(
                    f'{self.endpoint}/api/v1/namespaces/{self.namespace}/services/{name}',
                    timeout=30
                )

                if response.status_code == 200:
                    self.results[f'{result_prefix}_exists'] = True
                    svc = response.json()

                    # Check service type
                    if 'type' in svc_spec:
                        svc_type = svc.get('spec', {}).get('type', 'ClusterIP')
                        self.results[f'{result_prefix}_type_correct'] = (svc_type == svc_spec['type'])

                    # Check if headless (clusterIP: None)
                    if svc_spec.get('clusterIP') == 'None':
                        cluster_ip = svc.get('spec', {}).get('clusterIP')
                        self.results[f'{result_prefix}_is_headless'] = (cluster_ip == 'None')
                else:
                    self.results[f'{result_prefix}_exists'] = False

            except Exception as e:
                print(f"Error checking service {name}: {e}")
                self.results[f'{result_prefix}_exists'] = False

    def check_pvcs(self):
        """
        Check persistent volume claims
        """
        statefulsets = self.task_spec.get('required_resources', {}).get('statefulsets', [])

        for sts_spec in statefulsets:
            if 'volumeClaimTemplates' in sts_spec:
                name = sts_spec['name']
                replicas = sts_spec.get('replicas', 1)

                try:
                    response = self.session.get(
                        f'{self.endpoint}/api/v1/namespaces/{self.namespace}/persistentvolumeclaims',
                        timeout=30
                    )

                    if response.status_code == 200:
                        pvcs = response.json().get('items', [])
                        # Check if PVCs exist for statefulset
                        sts_pvcs = [pvc for pvc in pvcs if sts_spec['name'] in pvc['metadata']['name']]
                        self.results[f'statefulset_{name}_pvcs_created'] = len(sts_pvcs) >= replicas
                    else:
                        self.results[f'statefulset_{name}_pvcs_created'] = False

                except Exception as e:
                    print(f"Error checking PVCs for {name}: {e}")
                    self.results[f'statefulset_{name}_pvcs_created'] = False

    def check_pods(self):
        """
        Check pod status and count
        """
        try:
            response = self.session.get(
                f'{self.endpoint}/api/v1/namespaces/{self.namespace}/pods',
                timeout=30
            )

            if response.status_code == 200:
                pods = response.json().get('items', [])

                # Check pod count and status per resource
                deployments = self.task_spec.get('required_resources', {}).get('deployments', [])
                for deploy_spec in deployments:
                    name = deploy_spec['name']
                    labels = deploy_spec.get('selector_labels', {})

                    # Filter pods by labels
                    matching_pods = [
                        pod for pod in pods
                        if all(pod.get('metadata', {}).get('labels', {}).get(k) == v for k, v in labels.items())
                    ]

                    expected_count = deploy_spec.get('replicas', 1)
                    self.results[f'deployment_{name}_pod_count_correct'] = (len(matching_pods) == expected_count)

                    running_count = sum(1 for pod in matching_pods if pod.get('status', {}).get('phase') == 'Running')
                    self.results[f'deployment_{name}_pods_running'] = (running_count == expected_count)

                # Check statefulset pods
                statefulsets = self.task_spec.get('required_resources', {}).get('statefulsets', [])
                for sts_spec in statefulsets:
                    name = sts_spec['name']
                    labels = sts_spec.get('selector_labels', {})

                    matching_pods = [
                        pod for pod in pods
                        if all(pod.get('metadata', {}).get('labels', {}).get(k) == v for k, v in labels.items())
                    ]

                    expected_count = sts_spec.get('replicas', 1)
                    self.results[f'statefulset_{name}_pod_count_correct'] = (len(matching_pods) == expected_count)

                    running_count = sum(1 for pod in matching_pods if pod.get('status', {}).get('phase') == 'Running')
                    self.results[f'statefulset_{name}_pods_running'] = (running_count == expected_count)

        except Exception as e:
            print(f"Error checking pods: {e}")

    def run_application_checks(self):
        """
        Run HTTP endpoint checks defined in task spec
        """
        app_checks = self.task_spec.get('application_checks', [])

        for check in app_checks:
            check_id = check['check_id']
            check_type = check['check_type']

            try:
                if check_type == 'http_get':
                    self.results[check_id] = self.http_get_check(check)
                elif check_type == 'http_post':
                    self.results[check_id] = self.http_post_check(check)
            except Exception as e:
                print(f"Error running application check {check_id}: {e}")
                self.results[check_id] = False

    def http_get_check(self, check):
        """
        Perform HTTP GET check
        """
        service = check.get('service')
        port = check.get('port', 80)
        path = check.get('path', '/')
        target_pod = check.get('target_pod')
        timeout = check.get('timeout', 30)

        # Build URL
        if target_pod:
            # Direct pod access
            url = f'http://{target_pod}.{service}.{self.namespace}.svc.cluster.local:{port}{path}'
        else:
            # Service access
            url = f'http://{service}.{self.namespace}.svc.cluster.local:{port}{path}'

        # Note: This won't work directly from Lambda (outside cluster)
        # We need to use kubectl port-forward or exec into a pod
        # For now, return false as we can't reach internal cluster services from Lambda
        print(f"HTTP check {check['check_id']}: Cannot reach internal service from Lambda")
        return False

    def http_post_check(self, check):
        """
        Perform HTTP POST check
        """
        # Similar limitation as http_get_check
        print(f"HTTP POST check {check['check_id']}: Cannot reach internal service from Lambda")
        return False

    def run_probe_checks(self):
        """
        Check if probes are configured correctly
        """
        probe_checks = self.task_spec.get('probe_checks', [])

        for check in probe_checks:
            check_id = check['check_id']
            deployment_name = check.get('deployment')
            probe_type = check.get('probe_type')  # startup, liveness, readiness

            try:
                response = self.session.get(
                    f'{self.endpoint}/apis/apps/v1/namespaces/{self.namespace}/deployments/{deployment_name}',
                    timeout=30
                )

                if response.status_code == 200:
                    deployment = response.json()
                    containers = deployment.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])

                    if containers:
                        probe_key = f'{probe_type}Probe'
                        probe = containers[0].get(probe_key)

                        if probe:
                            # Check probe configuration
                            http_get = probe.get('httpGet', {})
                            expected_path = check.get('path')

                            path_correct = (http_get.get('path') == expected_path) if expected_path else True

                            # Check additional parameters if specified
                            period_correct = True
                            if 'period_seconds' in check:
                                period_correct = probe.get('periodSeconds') == check['period_seconds']

                            failure_correct = True
                            if 'failure_threshold' in check:
                                failure_correct = probe.get('failureThreshold') == check['failure_threshold']

                            self.results[check_id] = path_correct and period_correct and failure_correct
                        else:
                            self.results[check_id] = False
                    else:
                        self.results[check_id] = False
                else:
                    self.results[check_id] = False

            except Exception as e:
                print(f"Error checking probe {check_id}: {e}")
                self.results[check_id] = False

    def run_custom_checks(self):
        """
        Run custom validation checks
        """
        custom_checks = self.task_spec.get('custom_checks', [])

        for check in custom_checks:
            check_id = check['check_id']
            # Custom checks would require more complex logic
            # For now, mark as not implemented
            print(f"Custom check {check_id}: Not implemented yet")
            self.results[check_id] = False

    def calculate_score(self, results):
        """
        Calculate total score based on task criteria
        """
        criteria = self.task_spec.get('scoring', {}).get('criteria', [])
        total_score = 0

        for criterion in criteria:
            criterion_id = criterion['id']
            points = criterion['points']

            # Map criterion to result keys
            # This mapping handles different result key formats
            result_value = self.find_result_value(results, criterion_id)

            if result_value:
                total_score += points
                print(f"Criterion {criterion_id}: PASS (+{points} points)")
            else:
                print(f"Criterion {criterion_id}: FAIL (0 points)")

        return total_score

    def find_result_value(self, results, criterion_id):
        """
        Find result value for a criterion (handles different key formats)
        """
        # Direct match
        if criterion_id in results:
            return results[criterion_id]

        # Check for deployment-specific keys
        for key, value in results.items():
            if criterion_id in key:
                return value

        # Check for statefulset-specific keys
        for key, value in results.items():
            if criterion_id.replace('_', '-') in key:
                return value

        return False


def generate_results_summary(results, task_spec):
    """
    Generate a summary of results for the response
    """
    summary = {}
    criteria = task_spec.get('scoring', {}).get('criteria', [])

    for criterion in criteria:
        criterion_id = criterion['id']
        # Find matching result
        for key, value in results.items():
            if criterion_id in key:
                summary[criterion_id] = value
                break
        if criterion_id not in summary:
            summary[criterion_id] = False

    return summary
