import json
import boto3
import os
from datetime import datetime
import jwt

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

# JWT Secret for validating evaluation tokens (must match evaluator secret)
JWT_SECRET = os.environ.get('JWT_SECRET', os.environ.get('API_KEY', 'default-secret-change-me'))

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

        # Decode and validate JWT token
        try:
            eval_data = jwt.decode(eval_token, JWT_SECRET, algorithms=['HS256'])
            print(f"JWT token decoded successfully for {eval_data.get('student_id')}")
        except jwt.ExpiredSignatureError:
            return {
                'statusCode': 401,
                'body': json.dumps({
                    'error': 'Evaluation token has expired. Please run evaluation again.'
                })
            }
        except jwt.InvalidTokenError as e:
            return {
                'statusCode': 401,
                'body': json.dumps({
                    'error': 'Invalid evaluation token. Token may be corrupted or forged.',
                    'details': str(e)
                })
            }

        # Verify student_id and task_id match the JWT payload (prevent token reuse)
        if eval_data.get('student_id') != student_id:
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'error': 'Student ID mismatch. This token belongs to a different student.',
                    'expected': eval_data.get('student_id'),
                    'provided': student_id
                })
            }

        if eval_data.get('task_id') != task_id:
            return {
                'statusCode': 403,
                'body': json.dumps({
                    'error': 'Task ID mismatch. This token is for a different task.',
                    'expected': eval_data.get('task_id'),
                    'provided': task_id
                })
            }
        
        # Create official submission
        submission_timestamp = datetime.utcnow().isoformat()
        submission = {
            **eval_data,
            'eval_token': eval_token,  # Store JWT for audit trail
            'submission_timestamp': submission_timestamp,
            'submitted': True
        }
        
        # Store in submissions folder (consistent with evaluations path structure)
        submission_key = f'submissions/{student_id}/{task_id}/{submission_timestamp}.json'
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