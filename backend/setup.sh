#!/bin/bash

echo "🚀 Skechers Inventory System - Backend Setup"
echo "=============================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check Python version
echo "📋 Checking Python version..."
python_version=$(python3 --version 2>&1 | awk '{print $2}')
echo "   Found Python $python_version"

# Create virtual environment
echo ""
echo "📦 Creating virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "   ${GREEN}✓${NC} Virtual environment created"
else
    echo -e "   ${YELLOW}⚠${NC}  Virtual environment already exists"
fi

# Activate virtual environment
echo ""
echo "🔌 Activating virtual environment..."
source venv/bin/activate
echo -e "   ${GREEN}✓${NC} Virtual environment activated"

# Upgrade pip
echo ""
echo "⬆️  Upgrading pip..."
pip install --upgrade pip -q
echo -e "   ${GREEN}✓${NC} Pip upgraded"

# Install dependencies
echo ""
echo "📚 Installing dependencies (this may take a few minutes)..."
pip install -r requirements.txt -q
echo -e "   ${GREEN}✓${NC} Dependencies installed"

# Create .env if it doesn't exist
echo ""
if [ ! -f ".env" ]; then
    echo "⚙️  Creating .env configuration file..."
    cp .env.example .env
    echo -e "   ${GREEN}✓${NC} .env file created"
    echo -e "   ${YELLOW}⚠${NC}  Please edit .env with your database credentials"
else
    echo -e "   ${YELLOW}⚠${NC}  .env file already exists"
fi

# Create uploads directory
echo ""
echo "📁 Creating uploads directory..."
mkdir -p uploads/shoe_images
echo -e "   ${GREEN}✓${NC} Uploads directory created"

# Check for Tesseract
echo ""
echo "🔍 Checking for Tesseract OCR..."
if command -v tesseract &> /dev/null; then
    tesseract_version=$(tesseract --version 2>&1 | head -n 1)
    echo -e "   ${GREEN}✓${NC} $tesseract_version"
else
    echo -e "   ${YELLOW}⚠${NC}  Tesseract not found (optional for CV features)"
    echo "   Install with: brew install tesseract (macOS)"
    echo "             or: sudo apt-get install tesseract-ocr (Linux)"
fi

# Get local IP
echo ""
echo "🌐 Detecting local IP address..."
local_ip=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$local_ip" ]; then
    echo -e "   ${GREEN}✓${NC} Local IP: $local_ip"
    echo "   Configure iOS app with: http://$local_ip:8000"
else
    echo -e "   ${YELLOW}⚠${NC}  Could not detect IP address"
fi

# Summary
echo ""
echo "=============================================="
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Review and edit .env file if needed"
echo "2. Start the server: python fastapi_server.py"
echo "3. Configure iOS app with backend URL"
echo ""
echo "To activate virtual environment later:"
echo "  source venv/bin/activate"
echo ""
