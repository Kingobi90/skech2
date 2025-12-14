#!/usr/bin/env python3
"""
Quick test script to verify FastAPI server configuration
"""

import sys
from pathlib import Path

def test_imports():
    """Test that all required modules can be imported"""
    print("🧪 Testing imports...")
    
    try:
        import fastapi
        print("  ✅ FastAPI")
    except ImportError as e:
        print(f"  ❌ FastAPI: {e}")
        return False
    
    try:
        import uvicorn
        print("  ✅ Uvicorn")
    except ImportError as e:
        print(f"  ❌ Uvicorn: {e}")
        return False
    
    try:
        import openpyxl
        print("  ✅ OpenPyXL")
    except ImportError as e:
        print(f"  ❌ OpenPyXL: {e}")
        return False
    
    try:
        from openpyxl_image_loader import SheetImageLoader
        print("  ✅ OpenPyXL Image Loader")
    except ImportError as e:
        print(f"  ❌ OpenPyXL Image Loader: {e}")
        return False
    
    try:
        from pyxlsb import open_workbook
        print("  ✅ PyXLSB")
    except ImportError as e:
        print(f"  ❌ PyXLSB: {e}")
        return False
    
    try:
        from pynput.keyboard import Controller
        print("  ✅ Pynput")
    except ImportError as e:
        print(f"  ❌ Pynput: {e}")
        return False
    
    try:
        import pyautogui
        print("  ✅ PyAutoGUI")
    except ImportError as e:
        print(f"  ❌ PyAutoGUI: {e}")
        return False
    
    try:
        import pytesseract
        print("  ✅ PyTesseract")
    except ImportError as e:
        print(f"  ❌ PyTesseract: {e}")
        return False
    
    return True

def test_modules():
    """Test that custom modules can be imported"""
    print("\n🧪 Testing custom modules...")
    
    try:
        from app.services.excel_parser_enhanced import parse_excel_ki, parse_excel_allbought
        print("  ✅ Enhanced Excel Parser")
    except ImportError as e:
        print(f"  ❌ Enhanced Excel Parser: {e}")
        return False
    
    try:
        from app.core.database import SessionLocal
        print("  ✅ Database Module")
    except ImportError as e:
        print(f"  ❌ Database Module: {e}")
        return False
    
    try:
        from app.models.database_models import File
        print("  ✅ Database Models")
    except ImportError as e:
        print(f"  ❌ Database Models: {e}")
        return False
    
    return True

def test_directories():
    """Test that required directories exist"""
    print("\n🧪 Testing directories...")
    
    dirs = [
        Path("./uploads"),
        Path("./uploads/shoe_images"),
    ]
    
    for dir_path in dirs:
        if dir_path.exists():
            print(f"  ✅ {dir_path}")
        else:
            print(f"  ⚠️  {dir_path} (will be created)")
            dir_path.mkdir(parents=True, exist_ok=True)
            print(f"  ✅ Created {dir_path}")
    
    return True

def test_server_config():
    """Test that server can be configured"""
    print("\n🧪 Testing server configuration...")
    
    try:
        from fastapi_server import app
        print("  ✅ FastAPI app created")
        
        # Check routes
        routes = [route.path for route in app.routes]
        expected_routes = ["/", "/api/health", "/api/files/upload"]
        
        for route in expected_routes:
            if route in routes:
                print(f"  ✅ Route: {route}")
            else:
                print(f"  ❌ Route missing: {route}")
                return False
        
        return True
    except Exception as e:
        print(f"  ❌ Server configuration failed: {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    print("=" * 60)
    print("Skechers Inventory FastAPI Server - Test Suite")
    print("=" * 60)
    
    results = []
    
    results.append(("Imports", test_imports()))
    results.append(("Custom Modules", test_modules()))
    results.append(("Directories", test_directories()))
    results.append(("Server Config", test_server_config()))
    
    print("\n" + "=" * 60)
    print("Test Results:")
    print("=" * 60)
    
    all_passed = True
    for name, passed in results:
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"{status} - {name}")
        if not passed:
            all_passed = False
    
    print("=" * 60)
    
    if all_passed:
        print("\n🎉 All tests passed! Server is ready to start.")
        print("\nTo start the server, run:")
        print("  ./start_server.sh")
        print("  or")
        print("  python fastapi_server.py")
        return 0
    else:
        print("\n⚠️  Some tests failed. Please fix the issues above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
