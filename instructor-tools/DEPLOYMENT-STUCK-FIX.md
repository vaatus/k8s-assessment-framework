# Deployment Script Stuck at Docker Build - Fix

## Problem

The deployment script appears frozen at "Building images" because all output is redirected to `/dev/null`. Docker builds actually take 5-10 minutes.

## What's Happening

Docker is building:
1. **test-runner** image (for HTTP endpoint testing)
2. **kvstore** image (for task-02)

Each image downloads base images from Docker Hub and builds layers. First run takes longer due to caching.

---

## Immediate Solutions

### Option 1: Check If Images Already Exist in S3

```bash
# Check S3 for images
aws s3 ls s3://k8s-assessment-templates/docker-images/

# If you see test-runner.tar and kvstore.tar, you can skip building!
```

### Option 2: Kill and Skip Docker Build

```bash
# Kill the stuck process
pkill -f deploy-complete-setup.sh
pkill -f build-and-upload-images.sh

# Re-run and answer "no" to Docker build
cd instructor-tools
./deploy-complete-setup.sh

# When asked: "Build and upload Docker images? (yes/no) [default: yes]:"
# Answer: no
```

### Option 3: Wait It Out (If First Run)

If images DON'T exist in S3 yet:
- First run: 5-10 minutes (downloading base images)
- Subsequent runs: 2-3 minutes (cached layers)

Check progress in another terminal:
```bash
# Monitor Docker
docker ps -a
docker images

# Check if script is running
ps aux | grep build-and-upload
```

### Option 4: Build Images Manually With Visible Output

```bash
# Kill current process
pkill -f deploy-complete-setup.sh

# Run Docker build manually
cd instructor-tools
CONFIRM=yes bash build-and-upload-images.sh
# You'll see all Docker output

# After images are uploaded, re-run deploy script
./deploy-complete-setup.sh
# Answer "no" to Docker build (already done)
```

---

## Permanent Fix Applied

I've updated `deploy-complete-setup.sh` to **show Docker build progress** instead of hiding it.

**Before (line 125):**
```bash
CONFIRM=yes bash build-and-upload-images.sh >/dev/null 2>&1
```

**After (line 127):**
```bash
CONFIRM=yes bash build-and-upload-images.sh
```

Now you'll see:
- Docker build progress
- Upload progress to S3
- Estimated time remaining

---

## Next Deployment Run

After the fix, you'll see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Step 2/5: Building and Uploading Docker Images
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Docker detected
Build and upload Docker images? (yes/no) [default: yes]: yes
⏳ Building images (this may take 5-10 minutes)...
   💡 Progress shown below (or see log file for full details)

╔══════════════════════════════════════════════════════════╗
║  Build and Upload Docker Images to S3                    ║
╚══════════════════════════════════════════════════════════╝

Building test-runner...
[+] Building 34.5s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => => transferring dockerfile: 123B
 => [internal] load .dockerignore
 ...
Uploading test-runner.tar to S3...
upload: test-runner.tar to s3://k8s-assessment-templates/docker-images/

Building kvstore...
...

✅ Images built and uploaded to S3
```

---

## Recommended Action Now

**If images already exist in S3:**
```bash
pkill -f deploy-complete-setup.sh
cd instructor-tools
./deploy-complete-setup.sh
# Answer "no" to Docker build
```

**If this is first deployment:**
```bash
# Just wait 5-10 minutes, or
pkill -f deploy-complete-setup.sh

# Run with visible output
cd instructor-tools
CONFIRM=yes bash build-and-upload-images.sh

# Then complete deployment
./deploy-complete-setup.sh
# Answer "no" to Docker build
```

---

## Summary

- ❌ **Old behavior:** Silent build (appears frozen)
- ✅ **New behavior:** Shows progress
- ⏱️ **Build time:** 5-10 minutes first run, 2-3 minutes cached
- 🔄 **Can skip:** If images already in S3
