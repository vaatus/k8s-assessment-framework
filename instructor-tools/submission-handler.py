import json
import boto3
from datetime import datetime

s3 = boto3.client('s3')
BUCKET_NAME = 'k8s-eval-results'

def lambda_handler(event, context):
    """
    Handle final submission from student
    Requires: eval_token (from previous evaluation)
    """
    
    try:
        body = json.loads(event['body']) if 'body' in event else event
        student_id = body['student_id']
        task_id = body['task_id']
        eval_token = body['eval_token']
        
        # Verify evaluation exists
        eval_key = f'evaluations/{student_id}/{task_id}/{eval_token}.json'
        
        try:
            response = s3.get_object(Bucket=BUCKET_NAME, Key=eval_key)
            eval_data = json.loads(response['Body'].read())
        except s3.exceptions.NoSuchKey:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Evaluation token not found. Run evaluation first.'})
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
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Submission successful',
                'submission_id': submission_timestamp,
                'score': eval_data['score']
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }