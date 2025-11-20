#!/bin/bash
# Session End Hook (Optional)
# Runs automatically when session ends (D014 protocol)
#
# Purpose: Perform cleanup/documentation tasks at session end
# - Update session journal
# - Verify all work committed
# - Update issue tracker
#
# To enable: Make executable (chmod +x session-end.sh)
# To disable: Remove executable permission (chmod -x session-end.sh)

# Exit on error
set -e

echo "=== Session End ==="
echo "Date: $(date)"
echo ""

# Example: Verify no uncommitted changes
echo "Checking for uncommitted changes..."
if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  WARNING: Uncommitted changes detected"
    git status --short
else
    echo "✅ Working directory clean"
fi
echo ""

# Example: Show commits from this session
echo "Commits This Session:"
git log --oneline --since="2 hours ago"
echo ""

# Example: Remind to update issues
echo "📝 Remember to:"
echo "  - Update GitHub issues with completion status"
echo "  - Create session journal entry"
echo "  - Update CHANGELOG if user-facing changes"
echo ""

echo "=== Session Complete ==="
