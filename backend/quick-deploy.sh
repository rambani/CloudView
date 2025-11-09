#!/bin/bash

echo "🚀 CloudView Backend - Quick Deploy to Vercel"
echo "=============================================="
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "📦 Installing Vercel CLI..."
    npm install -g vercel
    echo ""
fi

echo "✅ Vercel CLI is installed"
echo ""

# Check if logged in
echo "🔐 Checking Vercel authentication..."
if ! vercel whoami &> /dev/null; then
    echo "❌ Not logged in to Vercel"
    echo ""
    echo "Please run: vercel login"
    echo ""
    exit 1
fi

echo "✅ Logged in to Vercel"
echo ""

# Navigate to backend directory
cd "$(dirname "$0")"

echo "📁 Current directory: $(pwd)"
echo ""

# Deploy
echo "🚀 Deploying to Vercel..."
echo ""

vercel --prod \
  --env UPSTASH_REDIS_REST_URL="https://flexible-moose-35374.upstash.io" \
  --env UPSTASH_REDIS_REST_TOKEN="AYouAAIncDIwOTZiNTY4ZGYxZTc0ZDI2OGVhODMzMjExMDhiMmRjN3AyMzUzNzQ"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "   1. Copy your deployment URL from above"
echo "   2. Test with: ./test-backend.sh <your-url>"
echo "   3. Update ScanReportingService.swift with your URL"
echo ""
