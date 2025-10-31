# Changelog

## [3.0.0] - 2025-10-31

### 🎯 Major Changes: Full Migration to Dynamic Evaluation

This release removes static evaluation components and improves deployment experience.

---

### ✅ Added

#### **Documentation**
- `tasks/task-spec.example.yaml` - Bitnami-style heavily commented task spec template
- `tasks/TASK_SPEC_GUIDE.md` - Quick guide to creating new tasks with examples
- `evaluation/lambda/archived/README.md` - Documentation for archived evaluators

#### **Features**
- Deployment logs now saved to timestamped file: `deployment-YYYYMMDD-HHMMSS.log`
- Cleaner console output with only essential information
- Progress indicators with emoji for better UX (⏳, ✅, ⚠️, ❌)

---

### 🔄 Changed

#### **Scripts**

**deploy-complete-setup.sh:**
- Removed evaluator selection prompt (always uses dynamic evaluator)
- All verbose output redirected to log file
- Console shows only progress and summary
- Added log file path reference: `deployment-YYYYMMDD-HHMMSS.log`
- Cleaner step separators with unicode box drawing
- Shortened Lambda endpoint display in summary

**reupload-template.sh:**
- Removed testing message: "The 'TaskSelection constraint' error should now be fixed!"
- Removed reference to fixing specific errors (was only for debugging)

#### **Documentation**

**README.md:**
- Removed "System Versions" section (Simple vs Advanced)
- Removed "Deployment Modes" section
- Replaced with "System Architecture" section
- Updated "For Developers" section to point to archived evaluators
- Updated status to reflect task-02 100/100 verification
- Updated last modified date to 2025-10-31

**README.md - Documentation Section:**
- Replaced reference to `task-spec-format.md` (274 lines of prose)
- Now references `TASK_SPEC_GUIDE.md` and `task-spec.example.yaml`
- Bitnami-style: learn by example, not by reading documentation

---

### 🗑️ Removed

#### **Files Moved to Archive**
- `evaluation/lambda/evaluator.py` → `evaluation/lambda/archived/evaluator.py`
- `evaluation/lambda/evaluator_v2.py` → `evaluation/lambda/archived/evaluator_v2.py`

These files are **deprecated** and kept only for reference.

#### **Removed from Scripts**
- Evaluator selection prompt (lines 140-157 in deploy-complete-setup.sh)
- Verbose AWS CLI output (redirected to log file)
- Testing/debugging messages from console output

---

### 📊 Comparison: Console Output

#### Before (Verbose):
```bash
Installing Python dependencies (PyYAML, requests)...
Requirement already satisfied: PyYAML in /usr/local/lib/python3.11/site-packages
Requirement already satisfied: requests in /usr/local/lib/python3.11/site-packages
...lots of pip output...
{
    "FunctionArn": "arn:aws:lambda:us-east-1:...",
    "FunctionName": "k8s-evaluation-function",
    ...50 lines of JSON...
}
The 'TaskSelection constraint' error should now be fixed!
```

#### After (Clean):
```bash
⏳ Packaging evaluation Lambda (dynamic evaluator)...
✅ Lambda package created (2.1M)
⏳ Creating evaluation Lambda...
✅ Evaluation Lambda deployed

📋 Detailed logs saved to: deployment-20251031-040730.log
```

---

### 🎨 Console Output Improvements

#### Progress Indicators
- ⏳ In progress
- ✅ Completed successfully
- ⚠️ Warning (non-fatal)
- ❌ Error (fatal)
- ⏭️ Skipped

#### Structured Output
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 3/5: Deploying Lambda Functions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 🏗️ System Architecture

#### Current (v3.0 - Production)
```
┌─────────────────────────────────────────┐
│ Dynamic Evaluation System               │
├─────────────────────────────────────────┤
│ • evaluator_dynamic.py (production)     │
│ • Task specs loaded from S3 (YAML)      │
│ • Supports task-01, task-02, task-03    │
│ • HTTP testing via test-runner pod      │
│ • Extensible: add tasks via YAML        │
└─────────────────────────────────────────┘
```

#### Deprecated (v1.0 - Archived)
```
┌─────────────────────────────────────────┐
│ Static Evaluation System                │
├─────────────────────────────────────────┤
│ • evaluator.py (archived)               │
│ • Hardcoded for task-01 only            │
│ • No HTTP testing support               │
│ • Not extensible                        │
└─────────────────────────────────────────┘
```

---

### 🧪 Testing Status

| Task    | Status | Score | Notes                      |
|---------|--------|-------|----------------------------|
| task-01 | ✅     | N/A   | Resource validation only   |
| task-02 | ✅     | 100   | Fully tested with HTTP     |
| task-03 | ✅     | N/A   | Ready, not yet tested      |

---

### 📝 Migration Notes

If you were using the old static evaluator:

1. **No action needed** - The deployment script now automatically uses the dynamic evaluator
2. **Old evaluators archived** - Available in `evaluation/lambda/archived/` for reference
3. **Task specs** - All tasks now use YAML specifications from S3
4. **Logs** - Check `deployment-*.log` for detailed deployment output

---

### 🎯 Breaking Changes

**None** - This is a backward-compatible cleanup:
- Student-facing functionality unchanged
- Lambda functions work identically
- Task evaluation results unchanged
- API endpoints unchanged

Only internal implementation and deployment experience improved.

---

## [2.0.0] - 2025-10-30

### Added
- Dynamic evaluation system with `evaluator_dynamic.py`
- Task specifications (YAML format)
- HTTP endpoint testing via test-runner pod
- Automated Docker image deployment
- `DYNAMIC_SETUP_TESTING_GUIDE.md`

### Changed
- Evaluation now driven by task specs
- Test-runner pod executes application checks

---

## [1.0.0] - 2025-10-23

### Added
- Initial release with static evaluator
- Support for task-01 (NGINX deployment)
- CloudFormation-based student deployment
- S3 storage for results
- Lambda functions for evaluation and submission

---

**Legend:**
- ✅ Implemented and tested
- 🚧 In progress
- 📋 Planned
- ❌ Deprecated

