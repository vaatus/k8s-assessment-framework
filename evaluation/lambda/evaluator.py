import json
import boto3
import os
from datetime import datetime
import uuid
import base64
import subprocess
import tempfile

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

def lambda_handler(event, context):
    """
    Remote evaluation Lambda triggered by student
    Receives: student_id, task_id, cluster_endpoint, cluster_token
    Returns: evaluation_token
    """
    
    try:
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

        # Test API connectivity with curl
        result = subprocess.run([
            'curl', '-k', '-s', '--connect-timeout', '10',
            '-H', f'Authorization: Bearer {token}',
            f'{server}/api/v1/namespaces/task-{task_id}'
        ], capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            # Check if response contains namespace info or 404
            if 'NotFound' in result.stdout:
                return {
                    'success': False,
                    'error': f'Namespace task-{task_id} not found'
                }
            elif '"kind":"Namespace"' in result.stdout:
                return {'success': True}
            else:
                return {'success': True}  # API is accessible
        else:
            return {
                'success': False,
                'error': f'Cannot connect to cluster API: {result.stderr}'
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

    namespace = f'task-{task_id}'

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

    # Check if deployment exists
    try:
        result = subprocess.run([
            'curl', '-k', '-s', '--connect-timeout', '10',
            '-H', f'Authorization: Bearer {token}',
            f'{server}/apis/apps/v1/namespaces/{namespace}/deployments/nginx-web'
        ], capture_output=True, text=True, timeout=30)

        if result.returncode == 0 and 'NotFound' not in result.stdout:
            results['deployment_exists'] = True
            deployment = json.loads(result.stdout)

            # Check replicas
            desired_replicas = deployment.get('spec', {}).get('replicas', 0)
            results['replicas_correct'] = (desired_replicas == 3)

            # Check image
            containers = deployment.get('spec', {}).get('template', {}).get('spec', {}).get('containers', [])
            if containers:
                image = containers[0].get('image', '')
                results['image_correct'] = ('nginx:1.25' in image)

                # Check resources
                resources = containers[0].get('resources', {})
                limits = resources.get('limits', {})
                results['resources_set'] = ('cpu' in limits and 'memory' in limits)

            # Check labels
            labels = deployment.get('metadata', {}).get('labels', {})
            results['labels_correct'] = (labels.get('app') == 'nginx-web')

    except Exception as e:
        print(f"Error checking deployment: {e}")

    # Check if pods are running
    try:
        result = subprocess.run([
            'curl', '-k', '-s', '--connect-timeout', '10',
            '-H', f'Authorization: Bearer {token}',
            f'{server}/api/v1/namespaces/{namespace}/pods?labelSelector=app=nginx-web'
        ], capture_output=True, text=True, timeout=30)

        if result.returncode == 0 and 'NotFound' not in result.stdout:
            pods = json.loads(result.stdout)
            pod_items = pods.get('items', [])

            results['pod_count_correct'] = (len(pod_items) == 3)

            # Check if all pods are running
            running_count = 0
            for pod in pod_items:
                phase = pod.get('status', {}).get('phase', '')
                if phase == 'Running':
                    running_count += 1

            results['pods_running'] = (running_count == 3)

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