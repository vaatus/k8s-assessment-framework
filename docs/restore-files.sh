#!/bin/bash
# Restoration Script for Archived Guide Files
# Created: 2025-10-31
# Purpose: Restore guide files to their original locations

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         Restoring Guide Files to Original Locations          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if we're in the correct directory
if [ ! -f "docs/FILE_MANIFEST.txt" ]; then
    echo "❌ Error: Please run this script from the repository root"
    echo "   Expected: /home/taha/k8s-assessment-framework"
    exit 1
fi

echo "📂 Restoring files from docs/ to original locations..."
echo ""

# Restore main setup guides
if [ -f "docs/guides/FULL_SETUP_GUIDE.md" ]; then
    mv docs/guides/FULL_SETUP_GUIDE.md ./
    echo "✅ Restored: FULL_SETUP_GUIDE.md"
else
    echo "⚠️  Not found: docs/guides/FULL_SETUP_GUIDE.md"
fi

if [ -f "docs/guides/MULTI_TASK_DEPLOYMENT_GUIDE.md" ]; then
    mv docs/guides/MULTI_TASK_DEPLOYMENT_GUIDE.md ./
    echo "✅ Restored: MULTI_TASK_DEPLOYMENT_GUIDE.md"
else
    echo "⚠️  Not found: docs/guides/MULTI_TASK_DEPLOYMENT_GUIDE.md"
fi

if [ -f "docs/guides/DYNAMIC_SETUP_TESTING_GUIDE.md" ]; then
    mv docs/guides/DYNAMIC_SETUP_TESTING_GUIDE.md ./
    echo "✅ Restored: DYNAMIC_SETUP_TESTING_GUIDE.md"
else
    echo "⚠️  Not found: docs/guides/DYNAMIC_SETUP_TESTING_GUIDE.md"
fi

# Restore task specification guide
if [ -f "docs/guides/TASK_SPEC_GUIDE.md" ]; then
    mv docs/guides/TASK_SPEC_GUIDE.md ./tasks/
    echo "✅ Restored: tasks/TASK_SPEC_GUIDE.md"
else
    echo "⚠️  Not found: docs/guides/TASK_SPEC_GUIDE.md"
fi

# Restore changelog
if [ -f "docs/CHANGELOG.md" ]; then
    mv docs/CHANGELOG.md ./
    echo "✅ Restored: CHANGELOG.md"
else
    echo "⚠️  Not found: docs/CHANGELOG.md"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  Restoration Complete! ✅                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📝 All guide files have been restored to their original locations."
echo ""
echo "🗑️  You can now safely delete the docs/ folder:"
echo "   rm -rf docs/"
echo ""
