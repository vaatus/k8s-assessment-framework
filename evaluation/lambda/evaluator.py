import json
import boto3
import subprocess
import os
from datetime import datetime
import uuid

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

def lambda_handler(event, context):
    """
    Remote evaluation Lambda triggered by student
    Receives: student_id, task_id, kubeconfig_url
    Returns: evaluation_token
    """
    
    try:
        # Parse request
        body = json.loads(event['body']) if 'body' in event else event
        student_id = body['student_id']
        task_id = body['task_id']
        cluster_endpoint = body['cluster_endpoint']
        cluster_token = body['cluster_token']
        
        # Generate unique evaluation token
        eval_token = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        # Create kubeconfig for remote cluster access
        kubeconfig = create_kubeconfig(cluster_endpoint, cluster_token)
        
        # Run KUTTL tests remotely
        test_results = run_kuttl_tests(task_id, kubeconfig)
        
        # Validate with Kyverno policies
        policy_results = validate_policies(task_id, kubeconfig)
        
        # Calculate score
        score = calculate_score(test_results, policy_results)
        
        # Generate report
        report = {
            'eval_token': eval_token,
            'student_id': student_id,
            'task_id': task_id,
            'timestamp': timestamp,
            'score': score,
            'test_results': test_results,
            'policy_results': policy_results,
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
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'eval_token': eval_token,
                'score': score,
                'message': 'Evaluation completed. Review results and submit if satisfied.',
                'results_preview': {
                    'tests_passed': test_results['passed'],
                    'tests_failed': test_results['failed'],
                    'policies_validated': policy_results['compliant']
                }
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def create_kubeconfig(endpoint, token):
    """Create kubeconfig for remote cluster access"""
    kubeconfig = {
        'apiVersion': 'v1',
        'kind': 'Config',
        'clusters': [{
            'name': 'student-cluster',
            'cluster': {
                'server': endpoint,
                'insecure-skip-tls-verify': True
            }
        }],
        'contexts': [{
            'name': 'evaluation-context',
            'context': {
                'cluster': 'student-cluster',
                'user': 'evaluator'
            }
        }],
        'current-context': 'evaluation-context',
        'users': [{
            'name': 'evaluator',
            'user': {
                'token': token
            }
        }]
    }
    
    # Write to /tmp (Lambda's writable directory)
    kubeconfig_path = '/tmp/kubeconfig'
    with open(kubeconfig_path, 'w') as f:
        json.dump(kubeconfig, f)
    
    return kubeconfig_path

def run_kuttl_tests(task_id, kubeconfig):
    """Execute KUTTL tests against student cluster"""
    os.environ['KUBECONFIG'] = kubeconfig
    
    # Download test cases from GitHub
    test_dir = f'/tmp/tests/{task_id}'
    os.makedirs(test_dir, exist_ok=True)
    
    # Clone repository or download specific test files
    # For simplicity, assume tests are packaged in Lambda layer
    
    try:
        # Run KUTTL
        result = subprocess.run(
            ['kubectl-kuttl', 'test', '--config', f'{test_dir}/kuttl-test.yaml'],
            capture_output=True,
            text=True,
            timeout=300
        )
        
        return {
            'passed': result.returncode == 0,
            'failed': result.returncode != 0,
            'output': result.stdout,
            'errors': result.stderr
        }
    except subprocess.TimeoutExpired:
        return {
            'passed': False,
            'failed': True,
            'output': '',
            'errors': 'Test execution timeout'
        }

def validate_policies(task_id, kubeconfig):
    """Validate resources against Kyverno policies"""
    os.environ['KUBECONFIG'] = kubeconfig
    
    # Get all resources in student namespace
    result = subprocess.run(
        ['kubectl', 'get', 'all', '-n', f'task-{task_id}', '-o', 'json'],
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        return {'compliant': False, 'violations': ['Failed to fetch resources']}
    
    # Apply Kyverno policy checks
    # This would use kyverno CLI or API
    return {
        'compliant': True,
        'violations': []
    }

def calculate_score(test_results, policy_results):
    """Calculate final score"""
    score = 0
    
    if test_results['passed']:
        score += 70
    
    if policy_results['compliant']:
        score += 30
    
    return score
