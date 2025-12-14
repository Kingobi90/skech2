#!/bin/bash

# Skechers Inventory Server Startup Script
# Starts the FastAPI server with enhanced features

echo "🚀 Starting Skechers Inventory FastAPI Server..."
echo ""

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "⚠️  Virtual environment not found. Creating one..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt

# Create necessary directories
mkdir -p uploads/shoe_images
mkdir -p logs

# Get local IP address
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")

echo ""
echo "✅ Server starting on:"
echo "   Local:   http://127.0.0.1:8000"
echo "   Network: http://$LOCAL_IP:8000"
echo ""
echo "📱 Configure this URL in your iOS app"
echo "⚠️  For keyboard typing: Place cursor in target field before scanning"
echo ""

# Start the FastAPI server
python fastapi_server.py
