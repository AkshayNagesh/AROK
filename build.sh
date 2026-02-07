#!/bin/bash

# AROK Build Script
# This script builds the AROK macOS app

set -e

echo "🚀 Building AROK..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode command line tools not found"
    echo "   Install with: xcode-select --install"
    exit 1
fi

# Build the project
xcodebuild -project AROK.xcodeproj \
           -scheme AROK \
           -configuration Release \
           -derivedDataPath build \
           clean build

echo "✅ Build complete!"
echo ""
echo "📦 App location: build/Build/Products/Release/AROK.app"
echo ""
echo "To run: open build/Build/Products/Release/AROK.app"
