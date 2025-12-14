# Skechers Showroom Inventory Management System - iOS App

High-performance iOS application built with SwiftUI for managing Skechers showroom inventory with offline-first architecture, computer vision scanning, and real-time synchronization.

## Features

### Core Functionality
- **Camera Scanning**: Scan shoe tags using AVFoundation with real-time OCR processing
- **Offline Support**: Complete local SQLite database with GRDB for offline operation
- **Real-time Sync**: Automatic and manual synchronization with backend server
- **Dual Workflows**: 
  - Sales Rep Mode: Product lookup and catalog building
  - Warehouse Mode: Coordinator classification and manager approval

### Performance Optimizations
- **Optimized UI**: Minimal blur effects, efficient list rendering with LazyVStack
- **Smart Caching**: NSCache for images, database query optimization
- **Smooth Animations**: Spring animations with explicit withAnimation blocks
- **Memory Management**: Proper image resizing and memory cleanup

### Design System
- **Minimalistic Black & White**: Pure black background with white UI elements
- **Glassy Components**: OptimizedGlassCard with optional blur for premium feel
- **Custom Tab Bar**: Performance-optimized custom navigation
- **Status Badges**: Color-coded visual feedback (green/orange/red)

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Open the project in Xcode
2. Install dependencies via Swift Package Manager:
   - GRDB.swift (6.24.0+)

3. Configure API endpoint in Settings:
   - Default: `https://api.yourdomain.com`
   - Update in app Settings screen

4. Build and run on device or simulator

## Project Structure

```
SkechersInventory/
├── SkechersInventoryApp.swift      # App entry point
├── ContentView.swift                # Main navigation container
├── Components/
│   ├── OptimizedGlassCard.swift    # Reusable glass card component
│   └── StatusBadge.swift            # Status indicator component
├── Views/
│   ├── HomeView.swift               # Dashboard with stats and quick actions
│   ├── InventoryView.swift          # Browse and search inventory
│   ├── WorkflowView.swift           # Sales Rep and Warehouse workflows
│   ├── SettingsView.swift           # App configuration and sync
│   ├── CameraScannerView.swift      # Camera interface for scanning
│   ├── ScanResultView.swift         # Display scan results
│   └── ManagerApprovalView.swift    # Swipeable approval interface
└── Managers/
    ├── DatabaseManager.swift        # SQLite database operations with GRDB
    ├── SyncManager.swift            # Data synchronization logic
    └── APIManager.swift             # REST API communication
```

## Database Schema

### Local SQLite Tables
- **styles**: Product style numbers with details (division, gender, outsole)
- **colors**: Colors associated with each style
- **showroom_inventory**: Items in showroom with locations and status
- **catalog_items**: Temporary catalog builder items
- **sync_log**: Synchronization history and timestamps

## API Integration

The app communicates with the Python Flask backend via REST API:

### Endpoints Used
- `POST /api/cv/detect` - Process shoe tag images
- `GET /api/lookup` - Lookup style and color
- `POST /api/warehouse/classify` - Submit classification
- `GET /api/warehouse/pending` - Get pending approvals
- `POST /api/warehouse/approve` - Approve/reject items
- `GET /api/sync` - Full data sync
- `GET /api/sync/changes` - Incremental sync
- `GET /api/admin/stats` - System statistics

## Usage

### Sales Rep Mode

1. **Scan Shoe**: 
   - Tap "Scan Shoe" from Home or Workflow
   - Align shoe tag within frame
   - Capture image
   - View results with style info and status

2. **Build Catalog**:
   - Scan multiple shoes in succession
   - Export as CSV file
   - Share via email, AirDrop, or Files app

### Warehouse Mode

1. **Coordinator**:
   - Scan incoming shoes
   - System auto-classifies as Keep/Wait/Drop
   - Confirm classification
   - Items sent to manager queue

2. **Manager**:
   - Review pending items in swipeable cards
   - Swipe right to approve (Keep)
   - Swipe left to reject (Drop)
   - Approved items ready for placement

3. **Placement**:
   - Assign shelf locations to approved items
   - Track showroom inventory

## Synchronization

### Full Sync
- Downloads complete dataset from server
- Runs on first launch or after 24+ hours
- Updates local database with all styles and placements

### Incremental Sync
- Downloads only changes since last sync
- Runs every 60 seconds in warehouse mode
- Minimal bandwidth usage

### Offline Operation
- All lookups work offline using local database
- Scans queue for upload when online
- Seamless online/offline transitions

## Performance Best Practices

### Implemented Optimizations
- ✅ LazyVStack/LazyHStack for list rendering
- ✅ Minimal blur effects (only on static elements)
- ✅ Lightweight shadows (opacity 0.1-0.15, radius 2-4)
- ✅ Image resizing and caching
- ✅ Explicit animations with withAnimation
- ✅ Database query optimization with indexes
- ✅ Background thread processing for heavy operations

### UI Guidelines
- Pure black background (#000000)
- White text and UI elements
- 5-8% white opacity for card backgrounds
- 10-15% white opacity for borders
- SF Pro font family throughout
- 16-20pt corner radius for cards
- 24pt edge margins

## Configuration

### User Defaults Keys
- `userName` - User's display name
- `apiEndpoint` - Backend API URL
- `deviceId` - Unique device identifier
- `lastSyncDate` - Last successful sync timestamp
- `autoSyncEnabled` - Auto-sync toggle
- `syncInterval` - Sync interval in seconds

## Troubleshooting

### Camera Not Working
- Check camera permissions in Settings > Privacy
- Ensure running on physical device (simulator has limited camera)

### Sync Failures
- Verify API endpoint in Settings
- Check network connectivity
- Review backend server logs

### Performance Issues
- Clear cache in Settings > Data Management
- Reduce sync interval if on slow network
- Check for large images in cache

## Building for Production

1. Update API endpoint to production URL
2. Configure code signing and provisioning
3. Set build configuration to Release
4. Archive and upload to App Store Connect
5. Submit for TestFlight or App Store review

## Future Enhancements

- [ ] Push notifications for manager approvals
- [ ] Barcode scanning support
- [ ] Advanced search filters
- [ ] Export options (PDF, Excel)
- [ ] Multi-language support
- [ ] Dark/Light mode toggle
- [ ] Haptic feedback
- [ ] Widget support

## License

Proprietary - Skechers Showroom Inventory Management System
