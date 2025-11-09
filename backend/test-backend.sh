#!/bin/bash

# Test script for CloudView backend

if [ -z "$1" ]; then
    echo "Usage: ./test-backend.sh <your-vercel-url>"
    echo "Example: ./test-backend.sh https://cloudview-backend.vercel.app"
    exit 1
fi

BACKEND_URL=$1

echo "🧪 Testing CloudView Backend"
echo "============================"
echo "Backend URL: $BACKEND_URL"
echo ""

# Test 1: Health check
echo "1️⃣  Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s "$BACKEND_URL/api/health")
echo "Response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

echo ""

# Test 2: Report scan
echo "2️⃣  Testing scan reporting..."
REPORT_RESPONSE=$(curl -s -X POST "$BACKEND_URL/api/report-scan" \
    -H "Content-Type: application/json" \
    -d '{
        "region": "San Francisco",
        "category": "animals",
        "timestamp": "2025-11-09T10:30:00Z"
    }')
echo "Response: $REPORT_RESPONSE"

if echo "$REPORT_RESPONSE" | grep -q "success"; then
    echo "✅ Scan reporting passed"
else
    echo "❌ Scan reporting failed"
    exit 1
fi

echo ""

# Test 3: Get regional activity
echo "3️⃣  Testing regional activity..."
ACTIVITY_RESPONSE=$(curl -s "$BACKEND_URL/api/regional-activity?region=San%20Francisco")
echo "Response: $ACTIVITY_RESPONSE"

if echo "$ACTIVITY_RESPONSE" | grep -q "San Francisco"; then
    echo "✅ Regional activity passed"
else
    echo "❌ Regional activity failed"
    exit 1
fi

echo ""
echo "🎉 All tests passed! Your backend is working correctly."
echo ""
echo "📋 Next steps:"
echo "   1. Update your iOS app with this backend URL: $BACKEND_URL/api/report-scan"
echo "   2. Enable the service in ScanReportingService.swift: isEnabled = true"
echo "   3. Build and test your app!"
