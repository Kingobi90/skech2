# Building Skechers Inventory iOS App from Terminal

## Prerequisites

1. **Xcode** (installed ✅)
2. **xcodegen** (installed ✅)
3. **Command Line Tools**:
   ```bash
   xcode-select --install
   ```

## Quick Build

### Option 1: Using Build Script (Recommended)
```bash
cd /Users/obinna.c/CascadeProjects/SkechersInventorySystem/ios
chmod +x build.sh
./build.sh
```

### Option 2: Manual Commands

**Step 1: Generate Xcode Project**
```bash
cd /Users/obinna.c/CascadeProjects/SkechersInventorySystem/ios
xcodegen generate
```

**Step 2: Build for Simulator**
```bash
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build
```

**Step 3: Run on Simulator**
```bash
# Open Simulator
open -a Simulator

# Build and run
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  run
```

## Build for Physical Device

```bash
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  clean build
```

**Note:** Building for device requires:
- Apple Developer account
- Code signing certificate
- Provisioning profile

## Common Commands

### List Available Simulators
```bash
xcrun simctl list devices
```

### List Available Schemes
```bash
xcodebuild -project SkechersInventory.xcodeproj -list
```

### Clean Build
```bash
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  clean
```

### Archive for Distribution
```bash
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  -configuration Release \
  -archivePath ./build/SkechersInventory.xcarchive \
  archive
```

## Using xcpretty (Optional)

For cleaner build output:

```bash
# Install xcpretty
gem install xcpretty

# Build with pretty output
xcodebuild ... | xcpretty
```

## Troubleshooting

### Error: "No such module 'GRDB'"
**Solution:** Clean and rebuild
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild clean
xcodebuild build
```

### Error: "Unable to boot simulator"
**Solution:** Reset simulator
```bash
xcrun simctl shutdown all
xcrun simctl erase all
```

### Error: "Code signing required"
**Solution:** 
1. Open project in Xcode: `open SkechersInventory.xcodeproj`
2. Select target → Signing & Capabilities
3. Select your development team

### Error: "Command PhaseScriptExecution failed"
**Solution:** Check build phases and script permissions

## Opening in Xcode GUI

If you prefer to use Xcode GUI:
```bash
open SkechersInventory.xcodeproj
```

Then press `Cmd + R` to build and run.

## Build Output Location

Built app location:
```
~/Library/Developer/Xcode/DerivedData/SkechersInventory-*/Build/Products/Debug-iphonesimulator/SkechersInventory.app
```

## Continuous Integration

For CI/CD pipelines:

```bash
# Set up environment
export CODE_SIGN_IDENTITY=""
export CODE_SIGNING_REQUIRED=NO
export CODE_SIGNING_ALLOWED=NO

# Build
xcodebuild \
  -project SkechersInventory.xcodeproj \
  -scheme SkechersInventory \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO
```

## Current Build Status

The build is currently running. It may take 2-5 minutes for the first build as it:
1. Fetches GRDB dependency from GitHub
2. Compiles Swift Package dependencies
3. Compiles app source files
4. Links frameworks

You can monitor progress in the terminal output.

## Next Steps After Build

1. **Test on Simulator**: Run the app and test camera scanning
2. **Configure API Endpoint**: Update Settings → API Endpoint
3. **Test Offline Mode**: Disable network and verify local database works
4. **Test Sync**: Enable network and verify data synchronization
5. **Build for Device**: Follow device build instructions above
