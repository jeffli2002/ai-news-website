#!/bin/bash
# auto-deploy.sh
# Automated deployment script for AI News Website

set -e  # Exit on any error

echo "🚀 Starting automated deployment of AI News Website..."

# Navigate to project directory
cd /home/jeffli/clawd/ai-news-website

echo "🔄 Syncing with remote repository..."

# Fetch the latest changes
git fetch origin

# Check if there are any commits that haven't been pushed
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
BASE=$(git merge-base HEAD origin/main)

if [ $LOCAL = $REMOTE ]; then
    echo "✅ Already up to date with remote repository"
elif [ $LOCAL = $BASE ]; then
    echo "⇣ There are remote changes, pulling latest..."
    git pull origin main --rebase
    echo "✅ Pulled latest changes from remote"
elif [ $REMOTE = $BASE ]; then
    echo "⇡ Pushing local changes to remote..."
    git push origin main
    echo "✅ Pushed local changes to remote"
else
    echo "⚠️  Diverged: Both local and remote have new commits"
    echo "Attempting to rebase..."
    git pull origin main --rebase
    git push origin main
    echo "✅ Resolved divergence and pushed changes"
fi

echo "🌐 Deployment preparation complete!"
echo ""
echo "💡 Note: Your Vercel deployment will automatically trigger once the push completes."
echo "   This may take a few minutes. You can monitor the deployment at:"
echo "   https://vercel.com/dashboard"
echo ""
echo "📋 Summary of changes:"
git log --oneline -5