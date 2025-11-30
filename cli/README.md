# kubeafr - Kubernetes Assessment Framework CLI

A unified command-line interface for the Kubernetes Assessment Framework, providing tools for both instructors and students.

```
╦╔═╦ ╦╔╗ ╔═╗╔═╗╔═╗╦═╗
╠╩╗║ ║╠╩╗║╣ ╠═╣╠╣ ╠╦╝
╩ ╩╚═╝╚═╝╚═╝╩ ╩╚  ╩╚═
Kubernetes Assessment Framework
```

## Overview

`kubeafr` is a modern CLI tool that unifies all instructor and student operations into a single, intuitive command. Think of it as "kubectl for Kubernetes assessment" - one command to rule them all!

**Features:**
- ✅ **Unified Interface**: Both instructor and student commands in one CLI
- ✅ **Beautiful Output**: Colorful, informative terminal output
- ✅ **Smart Aliases**: Quick shortcuts for common operations
- ✅ **Bash Completion**: Tab completion for commands and task IDs
- ✅ **Auto-Install**: Students get it automatically on their EC2 instances
- ✅ **Backward Compatible**: Old scripts still work

## Installation

### For Instructors

Install kubeafr on your local machine:

```bash
cd cli
./install-kubeafr.sh
```

The installer will:
1. Check Python dependencies (PyYAML, PyJWT)
2. Install missing packages (with permission)
3. Let you choose installation location:
   - `/usr/local/bin` (system-wide, requires sudo)
   - `~/.local/bin` (user only)
   - Custom path
4. Optionally install bash completion

### For Students

**You don't need to install anything!** kubeafr is automatically installed on your EC2 environment during setup.

## Usage

### For Instructors

####Deploy Infrastructure
```bash
kubeafr deploy
```
Deploys the complete assessment infrastructure including S3 buckets, Lambda functions, and CloudFormation templates.

#### Upload Task Specifications
```bash
kubeafr upload-specs
```
Uploads all task specifications to S3 for the dynamic evaluator.

#### View Student Results
```bash
# View all results
kubeafr view-results

# View results for a specific student
kubeafr view-results ABC123
```

#### Decode Evaluation Tokens
```bash
# Decode from token string
kubeafr decode-token eyJhbGciOi...

# Decode from file
kubeafr decode-token evaluation-results.json

# Show full JSON
kubeafr decode-token <token> --json
```

#### Validate Task Specifications
```bash
kubeafr validate-spec task-07
```

#### List All Tasks
```bash
kubeafr list-tasks
```

### For Students

#### Request Evaluation
```bash
kubeafr eval task-01

# Or use the shortcut alias
eval task-01
```

Sends your current Kubernetes configuration to the evaluator and returns your score with detailed feedback.

#### Submit Final Solution
```bash
kubeafr submit task-01

# Or use the shortcut alias
submit task-01

# Skip confirmation prompt
kubeafr submit task-01 -y
```

Submits your final solution to the instructor. This creates a permanent submission record.

#### Check Environment Status
```bash
kubeafr status
```

Shows:
- Your student information (Neptun code, assigned task)
- Kubernetes cluster status
- Node status
- Deployed resources in your namespace

#### List Available Tasks
```bash
kubeafr tasks
```

Lists all available tasks with their names and descriptions.

### Utility Commands

#### Check Prerequisites
```bash
kubeafr check-prereqs
```

#### Help & Version
```bash
kubeafr help
kubeafr version
```

## Command Reference

### Instructor Commands

| Command | Description |
|---------|-------------|
| `deploy` | Deploy complete assessment infrastructure |
| `upload-specs` | Upload task specifications to S3 |
| `view-results [student-id]` | View student evaluation results |
| `decode-token <token>` | Decode JWT evaluation tokens |
| `reupload-template` | Re-upload CloudFormation template |

### Student Commands

| Command | Aliases | Description |
|---------|---------|-------------|
| `eval <task-id>` | `eval` | Request evaluation of your solution |
| `submit <task-id>` | `submit` | Submit your final solution |
| `status` | `k8s-status` | Check environment status |
| `tasks` | `k8s-tasks` | List available tasks |

### Utility Commands

| Command | Description |
|---------|-------------|
| `validate-spec <task-id>` | Validate task specification |
| `list-tasks` | List all available tasks |
| `check-prereqs` | Check deployment prerequisites |

## Student Quick Start

When you SSH into your EC2 instance, you'll see a welcome message with all the commands. Here's a typical workflow:

```bash
# 1. Check your environment
kubeafr status

# 2. Go to your task directory
cd ~/k8s-workspace/tasks/task-01

# 3. Read the instructions
cat README.md

# 4. Create your Kubernetes manifests
vim solution.yaml

# 5. Apply your solution
kubectl apply -f solution.yaml

# 6. Verify it's working
kubectl get all -n task-01

# 7. Request evaluation (can do this multiple times)
kubeafr eval task-01

# 8. Review the feedback and iterate
#    Fix any issues, reapply, and evaluate again

# 9. When satisfied, submit your final solution
kubeafr submit task-01
```

## Shortcuts & Aliases

Students have these convenient aliases automatically configured:

```bash
# Instead of: kubeafr eval task-01
eval task-01

# Instead of: kubeafr submit task-01
submit task-01

# Instead of: kubeafr status
k8s-status

# Instead of: kubeafr tasks
k8s-tasks
```

## Environment Variables

### For Instructors

- `JWT_SECRET` or `API_KEY`: Secret key for JWT token verification

### For Students (Automatically Set)

The following are automatically configured in your `.bashrc`:

- `EVAL_ENDPOINT`: Evaluation Lambda endpoint
- `SUBMIT_ENDPOINT`: Submission Lambda endpoint
- `API_KEY`: API key for authentication

You don't need to worry about these - they're set up automatically!

## Bash Completion

Tab completion works for:
- Command names
- Task IDs
- File paths

Try it:
```bash
kubeafr <TAB>              # Shows all commands
kubeafr eval task-<TAB>    # Shows task-01, task-02, etc.
```

## Examples

### Instructor Workflow

```bash
# 1. Check everything is ready
kubeafr check-prereqs

# 2. Deploy infrastructure
kubeafr deploy

# 3. Upload task specifications
kubeafr upload-specs

# 4. Share landing page URL with students
# (URL is displayed after deployment)

# 5. Monitor student progress
kubeafr view-results

# 6. Decode student tokens for grading
kubeafr decode-token evaluation-results-task-01.json
```

### Student Workflow (Detailed)

```bash
# After logging in via SSH...

# Check what you're working on
kubeafr status

# See available tasks (though you're usually assigned one)
kubeafr tasks

# Navigate to your task
cd ~/k8s-workspace/tasks/task-01

# Read instructions carefully
less README.md

# Start working on your solution
vim deployment.yaml
vim service.yaml

# Apply your work
kubectl apply -f .

# Check if everything is running
kubectl get all -n task-01
kubectl logs <pod-name> -n task-01

# Request evaluation (you can do this many times!)
kubeafr eval task-01

# Example output:
# ✓ Evaluation complete!
#
# Score:  85/100 (85%)
# Status: passed
#
# Detailed Results:
#   ✓ deployment_exists
#   ✓ deployment_replicas_correct
#   ✓ pods_running
#   ✗ resource_limits_set
#   ✓ service_exists

# Fix the failing check
vim deployment.yaml  # Add resource limits
kubectl apply -f deployment.yaml

# Evaluate again
kubeafr eval task-01

# Once you get 100/100 (or are satisfied)
kubeafr submit task-01

# Confirm submission
# Are you sure? (yes/no): yes
#
# ✓ Submission successful!
# Your results have been submitted to the instructor.
```

## Backward Compatibility

The old scripts still work for compatibility with existing documentation:

```bash
~/student-tools/request-evaluation.sh task-01  # Redirects to: kubeafr eval
~/student-tools/submit-final.sh task-01         # Redirects to: kubeafr submit
```

They'll show a deprecation notice and then run the kubeafr command.

## Troubleshooting

### kubeafr command not found

**On instructor machine:**
Make sure the installation directory is in your PATH:

```bash
export PATH="$PATH:$HOME/.local/bin"  # For user installation
# or
export PATH="$PATH:/usr/local/bin"    # For system installation
```

Add this to your `~/.bashrc` to make it permanent.

**On student EC2:**
This shouldn't happen - kubeafr is installed to `/usr/local/bin` automatically. If it does:

```bash
# Restart your shell
exec bash
```

### Missing Python dependencies

Install required packages:

```bash
pip3 install PyYAML PyJWT
```

### Evaluation/Submission fails

1. Check environment variables are set:
   ```bash
   echo $EVAL_ENDPOINT
   echo $SUBMIT_ENDPOINT
   echo $API_KEY
   ```

2. Verify cluster is running:
   ```bash
   kubectl cluster-info
   kubectl get nodes
   ```

3. Check cluster info file:
   ```bash
   cat ~/.kube-assessment/cluster-info.json
   ```

4. Verify your resources are deployed:
   ```bash
   kubectl get all -n task-01
   ```

### Permission errors

If you get permission errors when running kubeafr on student instance:

```bash
sudo chmod +x /usr/local/bin/kubeafr
```

## Comparison: Old vs New

### Before (bash scripts)

```bash
# Students had to use long paths
~/student-tools/request-evaluation.sh task-01
~/student-tools/submit-final.sh task-01

# No status checking
# No task listing
# No help system
```

### After (kubeafr)

```bash
# Clean, simple commands
kubeafr eval task-01
kubeafr submit task-01

# Or even shorter with aliases
eval task-01
submit task-01

# Plus new features
kubeafr status
kubeafr tasks
kubeafr help
```

**Benefits:**
- Shorter commands
- Better error messages
- Colored, formatted output
- Additional utility commands
- Consistent interface
- Professional tool experience

## Development

### Project Structure

```
cli/
├── kubeafr              # Main CLI script (Python)
├── install-kubeafr.sh   # Installation script
├── k8s-assess           # Legacy instructor-only CLI
├── install.sh           # Legacy installer
└── README.md            # This file
```

### Adding New Commands

1. Add command function (`cmd_<name>`) to `kubeafr`
2. Add parser in `main()` function
3. Add to command routing dictionary
4. Update help text in docstring
5. Update this README

### Dependencies

- Python 3.6+
- PyYAML
- PyJWT
- curl (for HTTP requests)
- kubectl (for Kubernetes operations, student side only)
- jq (for JSON processing)

## Version History

- **v4.0.0** (2025-11) - kubeafr unified CLI with student and instructor commands
- **v3.0.0** (2025-10) - k8s-assess CLI (instructor only)
- **v2.0.0** - Individual bash scripts
- **v1.0.0** - Initial release

## Uninstallation

```bash
# Remove kubeafr
sudo rm /usr/local/bin/kubeafr

# Remove bash completion
sudo rm /etc/bash_completion.d/kubeafr
# or
rm ~/.bash_completion.d/kubeafr

# Remove Python packages (if not used elsewhere)
pip3 uninstall PyYAML PyJWT
```

## Support

For issues and questions:
- Run `kubeafr help` for quick help
- Check main project documentation in `docs/`
- Open GitHub issue

## See Also

- [Full Setup Guide](../docs/guides/FULL_SETUP_GUIDE.md)
- [Multi-Task Deployment Guide](../docs/guides/MULTI_TASK_DEPLOYMENT_GUIDE.md)
- [Task Specification Guide](../docs/guides/TASK_SPEC_GUIDE.md)
- [S3 Cost Optimization](../docs/S3-COST-OPTIMIZATION.md)

---

**Made with ❤️ for Kubernetes education**

**Version**: 4.0.0
**Last Updated**: 2025-11-21
