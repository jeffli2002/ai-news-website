#!/bin/bash

# deploy-to-vercel.sh
# Script to automate deployment of AI News Website to Vercel

set -e  # Exit on any error

echo "🚀 Starting deployment of AI News Website to Vercel..."

# Check if vercel is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found. Installing..."
    npm install -g vercel@latest
fi

# Navigate to project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

echo "📁 Project directory: $PROJECT_DIR"

# Check if frontend has been built
if [ ! -d "frontend/build" ]; then
    echo "📦 Building frontend..."
    cd frontend
    npm install
    npm run build
    cd ..
fi

# Check if backend dependencies are installed
if [ ! -f "backend/requirements.txt" ]; then
    echo "❌ Backend requirements.txt not found!"
    exit 1
fi

echo "🔍 Checking for Vercel configuration..."

# Check if vercel.json exists
if [ ! -f "vercel.json" ]; then
    echo "❌ vercel.json not found! Please create a vercel.json file first."
    exit 1
fi

echo "✅ Configuration looks good!"

# Check if we're logged into Vercel
if ! vercel whoami &> /dev/null; then
    echo "🔐 You are not logged in to Vercel. Please log in:"
    echo "   vercel login"
    echo "   Or set up your Vercel token as an environment variable."
    exit 1
fi

# Deploy to Vercel
echo " ↑ Deploying to Vercel..."
vercel --confirm --prod

echo "🎉 Deployment completed successfully!"
echo "🌐 Your application is now live at: $(vercel --scope $(vercel whoami) url)"

echo ""
echo "📋 Next steps:"
echo "- Visit your deployed application"
echo "- Configure custom domain if needed"
echo "- Set up environment variables if required"
echo "- Monitor your application performance"