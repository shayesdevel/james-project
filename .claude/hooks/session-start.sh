#!/bin/bash
# Session Start Hook (Optional)
# Runs automatically when new session starts
#
# Purpose: Perform setup tasks at session start
# - Verify environment is ready
# - Show project status
# - Reminder messages
#
# To enable: Make executable (chmod +x session-start.sh)
# To disable: Remove executable permission (chmod -x session-start.sh)

# Exit on error
set -e

echo "=== Session Start ==="
echo "Project: {YOUR_PROJECT_NAME}"
echo "Date: $(date)"
echo ""

# Example: Show git status
echo "Git Status:"
git status --short
echo ""

# Example: Show recent commits
echo "Recent Commits:"
git log --oneline -5
echo ""

# Example: Show open issues (GitHub)
# echo "Open Issues:"
# gh issue list --limit 5
# echo ""

# Example: Check services are running (Docker)
# echo "Service Status:"
# docker compose ps
# echo ""

echo "=== Ready to Work ==="
