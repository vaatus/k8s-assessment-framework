import json
import boto3
import os
from datetime import datetime
import uuid
import base64
import subprocess
import tempfile
import requests
import urllib3
from urllib3.exceptions import InsecureRequestWarning

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

def lambda_handler(event, context):
    """
    Remote evaluation Lambda triggered by student
    Receives: student_id, task_id, cluster_endpoint, cluster_token
    Returns: evaluation_token
    """

    try:
        # Validate API Key
        api_key = os.environ.get('API_KEY')
        if api_key:
            # Check for API key in headers
            headers = event.get('headers', {})
            # Handle case-insensitive headers
            request_api_key = headers.get('X-API-Key') or headers.get('x-api-key')

            if not request_api_key or request_api_key != api_key:
                return {
                    'statusCode': 401,
                    'body': json.dumps({
                        'error': 'Unauthorized',
                        'message': 'Invalid or missing API key'
                    })
                }

        # Parse request - handle both direct invoke and API Gateway
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
        
        # Generate unique evaluation token
        eval_token = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        print(f"Starting evaluation for student: {student_id}, task: {task_id}")
        
        # Create kubeconfig for remote cluster access
        kubeconfig_path = create_kubeconfig(cluster_endpoint, cluster_token)
        
        # Run basic connectivity test
        connectivity_test = test_cluster_connection(kubeconfig_path, task_id)
        
        if not connectivity_test['success']:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Cannot connect to student cluster',
                    'details': connectivity_test['error']
                })
            }
        
        # Evaluate the task
        evaluation_results = evaluate_task(task_id, kubeconfig_path)
        
        # Calculate score
        score = calculate_score(evaluation_results)
        
        # Generate report
        report = {
            'eval_token': eval_token,
            'student_id': student_id,
            'task_id': task_id,
            'timestamp': timestamp,
            'score': score,
            'max_score': 100,
            'results': evaluation_results,
            'status': 'completed'
        }
        
        # Store preliminary results (not final submission)
        result_key = f'evaluations/{student_id}/{task_id}/{eval_token}.json'
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=result_key,
            Body=json.dumps(report, indent=2),
            ContentType='application/json'
        )
        
        print(f"Evaluation completed. Score: {score}/100")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'eval_token': eval_token,
                'score': score,
                'max_score': 100,
                'message': 'Evaluation completed. Review results and submit if satisfied.',
                'results_summary': {
                    'deployment_exists': evaluation_results.get('deployment_exists', False),
                    'replicas_correct': evaluation_results.get('replicas_correct', False),
                    'image_correct': evaluation_results.get('image_correct', False),
                    'resources_set': evaluation_results.get('resources_set', False),
                    'pods_running': evaluation_results.get('pods_running', False)
                }
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

def create_kubeconfig(endpoint, token):
    """Create kubeconfig for remote cluster access"""
    
    kubeconfig_content = f"""apiVersion: v1
kind: Config
clusters:
- name: student-cluster
  cluster:
    server: {endpoint}
    insecure-skip-tls-verify: true
contexts:
- name: evaluation-context
  context:
    cluster: student-cluster
    user: evaluator
    namespace: default
current-context: evaluation-context
users:
- name: evaluator
  user:
    token: {token}
"""
    
    # Write to /tmp (Lambda's writable directory)
    kubeconfig_path = '/tmp/kubeconfig'
    with open(kubeconfig_path, 'w') as f:
        f.write(kubeconfig_content)
    
    print(f"Kubeconfig created at {kubeconfig_path}")
    return kubeconfig_path

def test_cluster_connection(kubeconfig_path, task_id):
    """Test connection to student cluster"""
    try:
        # Use curl to test the API endpoint directly since kubectl might not be available
        import json

        # Read kubeconfig to get server and token
        with open(kubeconfig_path, 'r') as f:
            import yaml
            kubeconfig = yaml.safe_load(f)

        server = kubeconfig['clusters'][0]['cluster']['server']
        token = kubeconfig['users'][0]['user']['token']

        # Test API connectivity with requests
        # Disable SSL verification for k3s self-signed certs
        session = requests.Session()
        session.verify = False
        urllib3.disable_warnings(InsecureRequestWarning)

        headers = {'Authorization': f'Bearer {token}'}
        # Test connection to task-specific namespace
        response = session.get(f'{server}/api/v1/namespaces/{task_id}',
                              headers=headers, timeout=30)

        if response.status_code == 200:
            return {'success': True}
        elif response.status_code == 404:
            return {
                'success': False,
                'error': f'Namespace {task_id} not found'
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

    except subprocess.TimeoutExpired:
        return {'success': False, 'error': 'Connection timeout'}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def evaluate_task(task_id, kubeconfig_path):
    """Evaluate task based on requirements"""

    results = {
        'deployment_exists': False,
        'replicas_correct': False,
        'image_correct': False,
        'resources_set': False,
        'labels_correct': False,
        'pods_running': False,
        'pod_count_correct': False
    }

    # Each task uses its own namespace
    namespace = task_id

    # Read kubeconfig to get server and token
    try:
        with open(kubeconfig_path, 'r') as f:
            import yaml
            kubeconfig = yaml.safe_load(f)

        server = kubeconfig['clusters'][0]['cluster']['server']
        token = kubeconfig['users'][0]['user']['token']
    except Exception as e:
        print(f"Error reading kubeconfig: {e}")
        return results

    # Set up requests session
    session = requests.Session()
    session.verify = False
    urllib3.disable_warnings(InsecureRequestWarning)
    headers = {'Authorization': f'Bearer {token}'}

    # Check if deployment exists
    try:
        response = session.get(
            f'{server}/apis/apps/v1/namespaces/{namespace}/deployments/nginx-web',
            headers=headers, timeout=30)

        if response.status_code == 200:
            results['deployment_exists'] = True
            deployment = response.json()

            # Check replicas (task-01 requires 2 replicas)
            desired_replicas = deployment.get('spec', {}).get('replicas', 0)
            results['replicas_correct'] = (desired_replicas == 2)

            # Check image (task-01 accepts nginx:latest or any nginx image)
            containers = deployment.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            if containers:
                image = containers[0].get('image', '')
                results['image_correct'] = ('nginx' in image.lower())

                # Check resources
                resources = containers[0].get('resources', {})
                limits = resources.get('limits', {})
                results['resources_set'] = ('cpu' in limits and 'memory' in limits)

            # Check labels (check pod template labels, not deployment metadata labels)
            pod_template_labels = deployment.get('spec', {}).get('template', {}).get('metadata', {}).get('labels', {})
            results['labels_correct'] = (pod_template_labels.get('app') == 'nginx')

    except Exception as e:
        print(f"Error checking deployment: {e}")

    # Check if pods are running
    try:
        response = session.get(
            f'{server}/api/v1/namespaces/{namespace}/pods?labelSelector=app=nginx',
            headers=headers, timeout=30)

        if response.status_code == 200:
            pods = response.json()
            pod_items = pods.get('items', [])

            results['pod_count_correct'] = (len(pod_items) == 2)

            # Check if all pods are running
            running_count = 0
            for pod in pod_items:
                phase = pod.get('status', {}).get('phase', '')
                if phase == 'Running':
                    running_count += 1

            results['pods_running'] = (running_count == 2)

    except Exception as e:
        print(f"Error checking pods: {e}")

    return results

def calculate_score(results):
    """Calculate final score based on evaluation results"""
    score = 0
    
    # Scoring rubric
    if results['deployment_exists']:
        score += 20
    if results['replicas_correct']:
        score += 15
    if results['image_correct']:
        score += 15
    if results['resources_set']:
        score += 20
    if results['labels_correct']:
        score += 10
    if results['pod_count_correct']:
        score += 10
    if results['pods_running']:
        score += 10
    
    return score