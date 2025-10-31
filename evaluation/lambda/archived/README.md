# Archived Evaluators

This directory contains deprecated evaluator versions for reference.

## Files

### evaluator.py (v1.0 - Static)
- **Status**: Deprecated
- **Supported Tasks**: task-01 only (NGINX deployment)
- **Evaluation Type**: Kubernetes resource validation only
- **Replaced By**: evaluator_dynamic.py

**Limitations:**
- Hardcoded for task-01
- No HTTP endpoint testing
- No test-runner pod support
- Cannot extend to new tasks

### evaluator_v2.py (v2.0 - Intermediate)
- **Status**: Deprecated
- **Purpose**: Experimental version during development
- **Replaced By**: evaluator_dynamic.py

---

## Current Evaluator

**evaluator_dynamic.py** (v3.0 - Production)
- ✅ Dynamic task loading from S3
- ✅ Supports all task types
- ✅ HTTP endpoint testing via test-runner pod
- ✅ Probe validation
- ✅ Fuzzy criterion matching
- ✅ Extensible for custom tasks

---

## Why These Were Archived

The static evaluators were replaced to achieve:
1. **Scalability**: Add new tasks without code changes
2. **Flexibility**: Task specs in YAML, not Python
3. **HTTP Testing**: Application-level validation
4. **Maintainability**: Single evaluator for all tasks

---

**Do not use these files in production.**
They are kept for historical reference only.
