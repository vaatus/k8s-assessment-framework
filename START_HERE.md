# 🎓 START HERE - Kubernetes Assessment Framework

## For Instructors: Complete Setup in 5 Minutes

### Step 1: Deploy Infrastructure

```bash
cd instructor-tools
./deploy-complete-setup.sh
```

**That's it!** This one command will:
- ✅ Create all S3 buckets
- ✅ Deploy all Lambda functions
- ✅ Generate API keys
- ✅ Configure CloudFormation template
- ✅ Create student landing page
- ✅ Display all URLs and credentials

### Step 2: Share with Students

You'll get a URL like:
```
https://k8s-assessment-templates.s3.us-east-1.amazonaws.com/index.html
```

**Share this URL with your students** - they can deploy their environment with one click!

### Step 3: View Results

```bash
cd instructor-tools
./view-results.sh
```

Interactive menu to view all student submissions.

---

## For Students: Deploy Your Environment

### Step 1: Visit Landing Page

Open the URL provided by your instructor.

### Step 2: Deploy

1. Click "Deploy My Environment" button
2. Enter your 6-character Neptun Code
3. Select your assigned task
4. Click "Create Stack"
5. Wait 5-10 minutes

### Step 3: Connect

Get your public IP from CloudFormation "Outputs" tab, then:

```bash
ssh -i ~/Downloads/labsuser.pem ubuntu@<PUBLIC-IP>
```

### Step 4: Complete Task

```bash
# Read welcome message
cat ~/welcome.txt

# Navigate to your task
cd ~/k8s-workspace/tasks/task-01

# Read instructions
cat README.md

# Create and apply your solution
nano solution.yaml
kubectl apply -f solution.yaml

# Request evaluation (can run multiple times)
~/student-tools/request-evaluation.sh task-01

# When satisfied, submit
~/student-tools/submit-final.sh task-01
```

---

## 📚 Documentation

- **README.md** - Complete documentation
- **QUICK_REFERENCE.md** - Command reference card
- **UNIFIED_SETUP_SUMMARY.md** - Detailed setup guide
- **TESTING_GUIDE.md** - Testing procedures

---

## 🆘 Need Help?

### For Instructors
- Check `README.md` troubleshooting section
- Review CloudWatch logs: `aws logs tail /aws/lambda/k8s-evaluation-function --follow`
- Verify S3 buckets: `aws s3 ls`

### For Students
- Read `~/welcome.txt` on your EC2 instance
- Check K3s status: `systemctl status k3s`
- View pod logs: `kubectl logs <pod-name>`
- Contact your instructor with error messages

---

## ✅ What You Get

### Instructors
- Complete evaluation infrastructure
- API key authentication
- Results storage in S3
- Interactive results viewer
- Student landing page

### Students
- Personal K3s cluster
- Pre-installed Kyverno
- Complete task workspace
- Evaluation tools
- Auto-cleanup after 4 hours

---

**Ready to start?**

**Instructors**: Run `./instructor-tools/deploy-complete-setup.sh`

**Students**: Visit the landing page URL from your instructor

🎉 **That's it!**
