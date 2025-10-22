#!/bin/bash
set -e

RESULTS_BUCKET="k8s-eval-results"
REGION="us-east-1"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Kubernetes Assessment - Student Results Viewer         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if bucket exists
if ! aws s3 ls "s3://${RESULTS_BUCKET}" 2>/dev/null; then
    echo "❌ Results bucket not found: ${RESULTS_BUCKET}"
    echo "   Run deploy-complete-setup.sh first"
    exit 1
fi

# Menu
echo "What would you like to view?"
echo ""
echo "  1. All submissions"
echo "  2. Submissions by Neptun Code"
echo "  3. Submissions by Task"
echo "  4. Latest evaluations"
echo "  5. Download all results"
echo ""
read -p "Choose option (1-5): " OPTION

case $OPTION in
    1)
        echo ""
        echo "=== All Submissions ==="
        echo ""
        aws s3 ls "s3://${RESULTS_BUCKET}/submissions/" --recursive --human-readable | tail -20
        ;;
    2)
        echo ""
        read -p "Enter Neptun Code: " NEPTUN
        echo ""
        echo "=== Submissions for ${NEPTUN} ==="
        echo ""
        aws s3 ls "s3://${RESULTS_BUCKET}/submissions/" --recursive | grep -i "${NEPTUN}" || echo "No submissions found"
        ;;
    3)
        echo ""
        read -p "Enter Task ID (e.g., task-01): " TASK
        echo ""
        echo "=== Submissions for ${TASK} ==="
        echo ""
        aws s3 ls "s3://${RESULTS_BUCKET}/submissions/" --recursive | grep "${TASK}" || echo "No submissions found"
        ;;
    4)
        echo ""
        echo "=== Latest Evaluations ==="
        echo ""
        aws s3 ls "s3://${RESULTS_BUCKET}/evaluations/" --recursive --human-readable | tail -20
        ;;
    5)
        echo ""
        DOWNLOAD_DIR="./student-results-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "${DOWNLOAD_DIR}"

        echo "Downloading all results to: ${DOWNLOAD_DIR}"
        aws s3 sync "s3://${RESULTS_BUCKET}/" "${DOWNLOAD_DIR}/" --region ${REGION}

        echo ""
        echo "✅ Results downloaded to: ${DOWNLOAD_DIR}"
        echo ""

        # Generate summary report
        echo "Generating summary report..."

        cat > "${DOWNLOAD_DIR}/summary.txt" <<EOF
Kubernetes Assessment - Results Summary
Generated: $(date)
========================================

Submissions Count: $(find "${DOWNLOAD_DIR}/submissions" -type f -name "*.json" 2>/dev/null | wc -l)
Evaluations Count: $(find "${DOWNLOAD_DIR}/evaluations" -type f -name "*.json" 2>/dev/null | wc -l)

Latest Submissions:
EOF

        find "${DOWNLOAD_DIR}/submissions" -type f -name "*.json" -exec ls -lh {} \; | tail -10 >> "${DOWNLOAD_DIR}/summary.txt"

        echo ""
        cat "${DOWNLOAD_DIR}/summary.txt"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

echo ""
echo "=== View Specific Result ==="
read -p "Enter S3 key to view (or press Enter to skip): " S3_KEY

if [ -n "$S3_KEY" ]; then
    echo ""
    aws s3 cp "s3://${RESULTS_BUCKET}/${S3_KEY}" - | jq '.' 2>/dev/null || aws s3 cp "s3://${RESULTS_BUCKET}/${S3_KEY}" -
fi

echo ""
echo "Done!"
