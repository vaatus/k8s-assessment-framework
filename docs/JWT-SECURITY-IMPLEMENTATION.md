# JWT Security Implementation

## Overview

The Kubernetes Assessment Framework uses **JWT (JSON Web Tokens)** to secure evaluation results and prevent students from fabricating or tampering with their scores.

## Why JWT?

**Problem**: Students could potentially:
- Fabricate evaluation results by guessing the JSON structure
- Modify scores in captured responses
- Replay old evaluation tokens for different tasks

**Solution**: JWT tokens are **cryptographically signed** and contain all evaluation data. Any tampering invalidates the signature.

## How It Works

### 1. Evaluation Flow (Evaluator Lambda)

```python
# Student requests evaluation → Lambda evaluates task
jwt_payload = {
    'student_id': 'TEST01',
    'task_id': 'task-05',
    'timestamp': '2025-11-02T23:00:00Z',
    'score': 100,
    'max_score': 100,
    'results': {...},  # Full evaluation results
    'status': 'completed'
}

# Sign with secret key (only Lambda knows this)
eval_token = jwt.encode(jwt_payload, JWT_SECRET, algorithm='HS256')

# Return to student
return {
    'eval_token': eval_token,  # JWT (signed)
    'score': 100,
    'max_score': 100,
    'message': 'Evaluation completed.',
    'results_summary': {...}
}
```

**Student receives**:
```json
{
  "eval_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdHVkZW50X2lkIjoiVEVTVDAxIiwidGFza19pZCI6InRhc2stMDUiLCJ0aW1lc3RhbXAiOiIyMDI1LTExLTAyVDIzOjAwOjAwWiIsInNjb3JlIjoxMDAsIm1heF9zY29yZSI6MTAwLCJyZXN1bHRzIjp7fSwic3RhdHVzIjoiY29tcGxldGVkIn0.signature_here",
  "score": 100,
  "max_score": 100,
  "message": "Evaluation completed.",
  "results_summary": { ... }
}
```

### 2. Submission Flow (Submitter Lambda)

```python
# Student submits eval_token → Lambda validates

# Decode and verify JWT signature
eval_data = jwt.decode(eval_token, JWT_SECRET, algorithms=['HS256'])

# Verify student_id and task_id match (prevent token reuse)
if eval_data['student_id'] != student_id:
    return error('Token belongs to different student')

if eval_data['task_id'] != task_id:
    return error('Token is for different task')

# Token is valid! Create submission
submission = {
    **eval_data,
    'eval_token': eval_token,
    'submission_timestamp': now,
    'submitted': True
}

# Store in S3
s3.put_object(..., submission)
```

## Security Properties

### ✅ Cannot Be Forged
- Token is signed with HMAC-SHA256
- Secret key stored only in Lambda environment variables
- Any modification breaks the signature → validation fails

### ✅ Self-Contained
- All evaluation data embedded in token
- No S3 lookup needed for validation (faster, more secure)
- Student cannot claim different score

### ✅ Prevents Token Reuse
- Submitter validates `student_id` and `task_id` match payload
- Student cannot use another student's token
- Student cannot use task-01 token for task-02

### ✅ Transparent to Students
- Student-facing response structure unchanged
- Only `eval_token` value changes (UUID → JWT)
- Students see their score in plaintext (same as before)

### ⚠️ Students Can Read Token Contents
- JWT is **signed**, not **encrypted**
- Students can decode (but not modify) the token
- This is acceptable: students already see their score in the response
- **Important**: Signature prevents tampering

## JWT Token Structure

### Header
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

### Payload (Evaluation Data)
```json
{
  "student_id": "TEST01",
  "task_id": "task-05",
  "timestamp": "2025-11-02T23:00:00.123Z",
  "score": 100,
  "max_score": 100,
  "results": {
    "statefulset_counter-app_exists": true,
    "statefulset_counter-app_replicas_correct": true,
    ...
  },
  "status": "completed"
}
```

### Signature
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  JWT_SECRET
)
```

## Configuration

### Environment Variables

Both Evaluator and Submitter Lambdas require:

```bash
# Primary: JWT-specific secret
JWT_SECRET="your-random-secret-key-here"

# Fallback: Uses API_KEY if JWT_SECRET not set
API_KEY="your-api-key"
```

**Recommendation**: Use the same value for both (set in deployment script).

### Generating a Secure Secret

```bash
# Generate a 64-character random hex string
openssl rand -hex 32

# Or use Python
python3 -c "import secrets; print(secrets.token_hex(32))"
```

## Instructor Tools

### Decode JWT Token

Instructors can decode tokens to view evaluation data:

```bash
# Using Python script
cd instructor-tools
./decode-jwt-token.py "eyJhbGciOi..."

# Or shell wrapper (auto-installs PyJWT)
./decode-jwt-token.sh "eyJhbGciOi..."

# From file
./decode-jwt-token.sh /path/to/token.txt
```

**Output:**
```
======================================================================
JWT TOKEN CONTENTS
======================================================================

Student ID:    TEST01
Task ID:       task-05
Score:         100/100
Timestamp:     2025-11-02T23:00:00.123Z
Status:        completed

Evaluation Criteria                           Result
----------------------------------------------------------------------
counter_get_value                             ✓ PASS
counter_increment                             ✓ PASS
counter_pod1_ready                            ✓ PASS
counter_ready                                 ✓ PASS
service_counter-service_exists                ✓ PASS
statefulset_counter-app_exists                ✓ PASS
statefulset_counter-app_has_volume_claims     ✓ PASS
statefulset_counter-app_pods_running          ✓ PASS
statefulset_counter-app_replicas_correct      ✓ PASS
----------------------------------------------------------------------
Total                                              9/9

✅ Token signature verified successfully
```

### Decode Without Verification (Read Only)

```python
import jwt

# Decode without verifying signature (just to read)
payload = jwt.decode(token, options={"verify_signature": False})
print(payload)
```

**Online tool**: https://jwt.io (paste token, won't verify signature without secret)

## Deployment

### 1. Update Lambda Functions

```bash
cd instructor-tools
./deploy-complete-setup.sh
```

This will:
- Install PyJWT dependency
- Deploy evaluator_dynamic.py with JWT generation
- Deploy submitter.py with JWT validation
- Set JWT_SECRET environment variable

### 2. Verify Deployment

```bash
# Test evaluation
~/student-tools/request-evaluation.sh task-01

# Check token format
# Should be long JWT (300-500 chars) instead of UUID (36 chars)
```

## S3 Storage Changes

### Before (UUID-based)
```
evaluations/TEST01/task-05/550e8400-e29b-41d4-a716-446655440000.json
```

### After (Timestamp-based)
```
evaluations/TEST01/task-05/2025-11-02T23:00:00.123456.json
```

**Reason**: JWT tokens are too long for filenames (~300-500 chars vs 36 char UUID).

**Impact**: None (S3 storage is for audit/backup only; JWT is source of truth).

## Migration from UUID

### Backward Compatibility

The system is **backward compatible**:

1. **Old tokens (UUID)**: Submitter tries JWT decode → fails → could fallback to S3 lookup (if implemented)
2. **New tokens (JWT)**: Submitter decodes JWT → validates → accepts

### Migration Steps

1. Deploy new Lambda functions
2. Students re-run evaluations → get JWT tokens
3. Students submit with JWT tokens → validated cryptographically
4. Old UUID tokens in student hands → expired (students must re-evaluate)

## Security Considerations

### ✅ Protections Enabled

- **Signature Verification**: Prevents tampering
- **Student ID Validation**: Prevents token theft
- **Task ID Validation**: Prevents task confusion
- **Secret Key Security**: Stored in Lambda environment (not in code)

### ⚠️ Potential Improvements (Future)

1. **Add Expiration**: Token expires after 24 hours
   ```python
   payload['exp'] = datetime.utcnow() + timedelta(hours=24)
   ```

2. **Add Nonce/JTI**: Prevent replay attacks
   ```python
   payload['jti'] = str(uuid.uuid4())  # JWT ID
   # Track used JTIs in DynamoDB
   ```

3. **Encrypt Payload**: Hide score from students (if desired)
   ```python
   # Use JWE (JSON Web Encryption) instead of JWT
   ```

## Troubleshooting

### "Invalid token" Error

**Cause**: Secret key mismatch between evaluator and submitter

**Fix**: Ensure both Lambdas have same JWT_SECRET:
```bash
aws lambda update-function-configuration \
  --function-name k8s-evaluation-function \
  --environment Variables="{JWT_SECRET=your-secret}"

aws lambda update-function-configuration \
  --function-name k8s-submission-function \
  --environment Variables="{JWT_SECRET=your-secret}"
```

### "Token belongs to different student" Error

**Cause**: Student trying to use another student's token

**Expected**: This is the security working correctly!

### Token Too Long for Terminal

**Solution**: Save token to file
```bash
# Student side
echo "$eval_token" > /tmp/token.txt

# Instructor side
./decode-jwt-token.sh /tmp/token.txt
```

## Testing

### Test JWT Generation

```python
import jwt

payload = {'student_id': 'TEST01', 'score': 100}
secret = 'test-secret'

token = jwt.encode(payload, secret, algorithm='HS256')
print(f"Token: {token}")

decoded = jwt.decode(token, secret, algorithms=['HS256'])
print(f"Decoded: {decoded}")
```

### Test Token Tampering

```python
# Try to modify token
parts = token.split('.')
# Modify payload (will break signature)
decoded = jwt.decode(modified_token, secret, algorithms=['HS256'])
# Raises: jwt.InvalidSignatureError
```

## References

- [JWT.io](https://jwt.io) - JWT debugger
- [RFC 7519](https://tools.ietf.org/html/rfc7519) - JWT specification
- [PyJWT Documentation](https://pyjwt.readthedocs.io/)

---

**Last Updated**: 2025-11-02
**Status**: ✅ Production Ready
