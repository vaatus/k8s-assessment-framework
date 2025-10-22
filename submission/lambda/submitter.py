import json
import boto3
import os
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

def lambda_handler(event, context):
    """
    Handle final submission from student
    Requires: eval_token (from previous evaluation)
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
        eval_token = body.get('eval_token')
        
        # Validate inputs
        if not all([student_id, task_id, eval_token]):
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required parameters: student_id, task_id, eval_token'
                })
            }
        
        # Verify evaluation exists
        eval_key = f'evaluations/{student_id}/{task_id}/{eval_token}.json'
        
        try:
            response = s3.get_object(Bucket=BUCKET_NAME, Key=eval_key)
            eval_data = json.loads(response['Body'].read())
        except s3.exceptions.NoSuchKey:
            return {
                'statusCode': 404,
                'body': json.dumps({
                    'error': 'Evaluation token not found. Please run evaluation first.'
                })
            }
        
        # Create official submission
        submission_timestamp = datetime.utcnow().isoformat()
        submission = {
            **eval_data,
            'submission_timestamp': submission_timestamp,
            'submitted': True
        }
        
        # Store in submissions folder
        submission_key = f'submissions/{task_id}/{student_id}/{submission_timestamp}.json'
        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=submission_key,
            Body=json.dumps(submission, indent=2),
            ContentType='application/json'
        )
        
        print(f"Submission recorded: {submission_key}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Submission successful',
                'submission_id': submission_timestamp,
                'score': eval_data['score'],
                'max_score': eval_data.get('max_score', 100),
                'task_id': task_id
            })
        }
        
    except Exception as e:
        print(f"Error during submission: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal submission error',
                'details': str(e)
            })
        }