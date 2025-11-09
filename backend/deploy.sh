#!/bin/bash

echo "🚀 CloudView Backend Deployment Script"
echo "========================================"
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI not found. Installing..."
    npm install -g vercel
fi

# Check if dependencies are installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

echo ""
echo "📝 Before deploying, make sure you have:"
echo "   1. Created an Upstash Redis database at https://console.upstash.com/"
echo "   2. Copied your UPSTASH_REDIS_REST_URL"
echo "   3. Copied your UPSTASH_REDIS_REST_TOKEN"
echo ""

read -p "Have you completed the above steps? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete the setup first, then run this script again."
    exit 1
fi

echo ""
echo "🚀 Deploying to Vercel..."
echo ""

# Deploy to Vercel
vercel --prod

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Copy your deployment URL from above"
echo "   2. Update CloudView/Services/ScanReportingService.swift:"
echo "      private let backendURL = \"https://YOUR-PROJECT.vercel.app/api/report-scan\""
echo "      private var isEnabled = true"
echo "   3. Test your backend: curl https://YOUR-PROJECT.vercel.app/api/health"
echo ""
echo "🎉 Your privacy-preserving backend is now live!"
