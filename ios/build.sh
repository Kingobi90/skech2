#!/bin/bash

# Skechers Inventory iOS App Build Script

echo "🔨 Building Skechers Inventory iOS App..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo -e "${RED}❌ xcodegen not found. Install with: brew install xcodegen${NC}"
    exit 1
fi

# Generate Xcode project
echo -e "${YELLOW}📦 Generating Xcode project...${NC}"
xcodegen generate

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to generate Xcode project${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Xcode project generated${NC}"
echo ""

# Build for simulator
echo -e "${YELLOW}🏗️  Building for iOS Simulator...${NC}"
xcodebuild \
    -project SkechersInventory.xcodeproj \
    -scheme SkechersInventory \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    clean build \
    | xcpretty || xcodebuild \
    -project SkechersInventory.xcodeproj \
    -scheme SkechersInventory \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
    clean build

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Build successful!${NC}"
    echo ""
    echo "📱 To run the app:"
    echo "   1. Open Simulator: open -a Simulator"
    echo "   2. Install app: xcrun simctl install booted <path-to-app>"
    echo "   3. Or run: xcodebuild -project SkechersInventory.xcodeproj -scheme SkechersInventory -destination 'platform=iOS Simulator,name=iPhone 15 Pro' run"
else
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
