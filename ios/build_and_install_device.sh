#!/bin/bash

# Skechers Inventory iOS App - Build and Install to Physical Device
# This script builds and installs the app to your connected iPhone

echo "🔨 Building and Installing Skechers Inventory to iPhone..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Device ID (Obinna's iPhone)
DEVICE_ID="00008150-001623C81E88401C"

# Check if device is connected
echo -e "${YELLOW}📱 Checking device connection...${NC}"
if ! xcrun xctrace list devices 2>&1 | grep -q "$DEVICE_ID"; then
    echo -e "${RED}❌ Device not found. Please connect your iPhone.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Device connected${NC}"
echo ""

# Build for device
echo -e "${YELLOW}🏗️  Building for iOS Device (arm64)...${NC}"
xcodebuild \
    -project SkechersInventory.xcodeproj \
    -scheme SkechersInventory \
    -configuration Debug \
    -sdk iphoneos \
    -destination "platform=iOS,id=$DEVICE_ID" \
    clean build

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Build successful!${NC}"
echo ""

# Install to device
echo -e "${YELLOW}📲 Installing app to device...${NC}"
APP_PATH="/Users/obinna.c/Library/Developer/Xcode/DerivedData/SkechersInventory-atvkfmtlaqqtracwrvtsbqxwbhib/Build/Products/Debug-iphoneos/SkechersInventory.app"

xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Installation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ App installed successfully!${NC}"
echo ""

# Launch the app
echo -e "${YELLOW}🚀 Launching app on device...${NC}"
xcrun devicectl device process launch --device "$DEVICE_ID" com.skechers.inventory

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ App launched successfully!${NC}"
    echo ""
    echo "📱 The Skechers Inventory app is now running on your iPhone!"
else
    echo ""
    echo -e "${YELLOW}⚠️  App installed but launch failed. Try opening it manually on your iPhone.${NC}"
fi
