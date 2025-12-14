#!/bin/bash

# Test script for Skechers Inventory API endpoints
# Usage: ./test_endpoints.sh [base_url]

BASE_URL="${1:-http://localhost:8000}"

echo "🧪 Testing Skechers Inventory API"
echo "===================================="
echo "Base URL: $BASE_URL"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_count=0
pass_count=0

test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    test_count=$((test_count + 1))
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    
    if [ "$response" -eq "$expected_code" ]; then
        echo -e "${GREEN}✓${NC} $name (HTTP $response)"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗${NC} $name (Expected $expected_code, got $response)"
    fi
}

echo "Testing Core Endpoints:"
echo "----------------------"
test_endpoint "Health Check" "$BASE_URL/health"
test_endpoint "System Stats" "$BASE_URL/api/admin/stats"
test_endpoint "Connected Devices" "$BASE_URL/api/devices/connected"

echo ""
echo "Testing File Endpoints:"
echo "----------------------"
test_endpoint "List Files" "$BASE_URL/api/files/"

echo ""
echo "Testing Warehouse Endpoints:"
echo "---------------------------"
test_endpoint "Get Pending Classifications" "$BASE_URL/api/warehouse/pending"
test_endpoint "Get Placements" "$BASE_URL/api/warehouse/placements"

echo ""
echo "Testing Admin Endpoints:"
echo "----------------------"
test_endpoint "Get Removal Tasks" "$BASE_URL/api/admin/removal-tasks"
test_endpoint "Get System Config" "$BASE_URL/api/admin/config"

echo ""
echo "===================================="
echo "Tests Passed: $pass_count/$test_count"

if [ $pass_count -eq $test_count ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed${NC}"
    exit 1
fi
