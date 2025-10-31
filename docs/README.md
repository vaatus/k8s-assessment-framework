# Documentation Archive

This directory contains archived guide documentation that has been moved from the root directory for better organization.

## 📁 Directory Structure

```
docs/
├── README.md                              # This file
├── FILE_MANIFEST.txt                      # Mapping of files to original locations
├── restore-files.sh                       # Script to restore files to original locations
├── CHANGELOG.md                           # Project changelog (v3.0)
└── guides/
    ├── FULL_SETUP_GUIDE.md               # Complete setup and testing guide (basic system)
    ├── MULTI_TASK_DEPLOYMENT_GUIDE.md    # Advanced multi-task system deployment
    ├── DYNAMIC_SETUP_TESTING_GUIDE.md    # Dynamic evaluation setup guide
    └── TASK_SPEC_GUIDE.md                # Quick guide to creating new tasks
```

## 📋 Archived Files (5 total)

### Main Setup Guides
1. **FULL_SETUP_GUIDE.md** - Complete deployment and testing guide for basic system
2. **MULTI_TASK_DEPLOYMENT_GUIDE.md** - Advanced multi-task system deployment
3. **DYNAMIC_SETUP_TESTING_GUIDE.md** - Dynamic evaluation setup with automated image deployment

### Task Development
4. **TASK_SPEC_GUIDE.md** - Quick guide to creating new task specifications

### Project History
5. **CHANGELOG.md** - Complete changelog (v1.0 → v3.0)

## 🔄 Restoring Files

To restore all files to their original locations:

### Option 1: Use the restoration script
```bash
cd /home/taha/k8s-assessment-framework
bash docs/restore-files.sh
```

### Option 2: Manual restoration
```bash
cd /home/taha/k8s-assessment-framework

# Restore setup guides
mv docs/guides/FULL_SETUP_GUIDE.md ./
mv docs/guides/MULTI_TASK_DEPLOYMENT_GUIDE.md ./
mv docs/guides/DYNAMIC_SETUP_TESTING_GUIDE.md ./

# Restore task guide
mv docs/guides/TASK_SPEC_GUIDE.md ./tasks/

# Restore changelog
mv docs/CHANGELOG.md ./

# Remove empty docs folder
rm -rf docs/
```

## 📝 Files Kept in Original Locations

These essential files were **NOT** moved:

### Root Directory
- `README.md` - Main project README (must stay in root for GitHub)

### Student Task Instructions
- `tasks/task-01/README.md` - NGINX deployment task
- `tasks/task-02/README.md` - StatefulSet task
- `tasks/task-03/README.md` - Health probes task

### Technical Documentation
- `evaluation/test-runner/README.md` - Test-runner pod documentation
- `evaluation/lambda/archived/README.md` - Explains deprecated evaluators

## 🎯 Why Files Were Archived

This reorganization was done to:
- ✅ Clean up root directory
- ✅ Organize instructor guides in dedicated location
- ✅ Keep student-facing docs in place (task READMEs)
- ✅ Maintain essential technical docs with code

## 📊 Summary

| Category | Count | Location |
|----------|-------|----------|
| **Archived Guides** | 5 | `docs/` |
| **Essential Docs** | 6 | Original locations |
| **Total Documentation** | 11 | Various |

---

**Created**: 2025-10-31
**Purpose**: Organize instructor guide documentation
**Restoration**: See `FILE_MANIFEST.txt` or run `restore-files.sh`
