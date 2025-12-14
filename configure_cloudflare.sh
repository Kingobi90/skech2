#!/bin/bash

# Cloudflare DNS Configuration Script for api.obinnachukwu.org

echo "========================================="
echo "Cloudflare DNS Configuration"
echo "========================================="
echo ""

# Check if required variables are set
if [ -z "$CF_API_TOKEN" ] && [ -z "$CF_API_KEY" ]; then
    echo "ERROR: Cloudflare credentials not set!"
    echo ""
    echo "You need to set ONE of the following:"
    echo ""
    echo "Option 1: API Token (Recommended)"
    echo "  export CF_API_TOKEN='your-api-token-here'"
    echo ""
    echo "  Get your API token from:"
    echo "  https://dash.cloudflare.com/profile/api-tokens"
    echo "  Click 'Create Token' → 'Edit zone DNS' template"
    echo ""
    echo "Option 2: Global API Key"
    echo "  export CF_API_KEY='your-global-api-key'"
    echo "  export CF_EMAIL='your-cloudflare-email@example.com'"
    echo ""
    echo "  Get your API key from:"
    echo "  https://dash.cloudflare.com/profile/api-tokens"
    echo "  Click 'View' next to Global API Key"
    echo ""
    exit 1
fi

# Set the target URL for your backend (you'll get this after deploying to Railway/Render/etc)
if [ -z "$BACKEND_URL" ]; then
    echo "ERROR: BACKEND_URL not set!"
    echo ""
    echo "Please set your backend hosting URL:"
    echo "  export BACKEND_URL='your-app.up.railway.app'"
    echo ""
    echo "Or for Render:"
    echo "  export BACKEND_URL='your-service.onrender.com'"
    echo ""
    exit 1
fi

DOMAIN="obinnachukwu.org"
SUBDOMAIN="api"
FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

echo "Configuration:"
echo "  Domain: $DOMAIN"
echo "  Subdomain: $SUBDOMAIN"
echo "  Full Domain: $FULL_DOMAIN"
echo "  Target: $BACKEND_URL"
echo ""

# Set auth headers based on which credentials are provided
if [ -n "$CF_API_TOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $CF_API_TOKEN"
else
    AUTH_HEADER="X-Auth-Key: $CF_API_KEY"
    EXTRA_HEADER="-H X-Auth-Email: $CF_EMAIL"
fi

echo "Step 1: Getting Zone ID for $DOMAIN..."
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
    -H "$AUTH_HEADER" \
    $EXTRA_HEADER \
    -H "Content-Type: application/json")

ZONE_ID=$(echo $ZONE_RESPONSE | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result'][0]['id'] if data.get('result') and len(data['result']) > 0 else '')" 2>/dev/null)

if [ -z "$ZONE_ID" ]; then
    echo "ERROR: Could not get Zone ID"
    echo "Response: $ZONE_RESPONSE"
    exit 1
fi

echo "✓ Zone ID: $ZONE_ID"
echo ""

echo "Step 2: Checking for existing DNS record..."
DNS_RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=$FULL_DOMAIN" \
    -H "$AUTH_HEADER" \
    $EXTRA_HEADER \
    -H "Content-Type: application/json")

EXISTING_RECORD_ID=$(echo $DNS_RECORDS | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['result'][0]['id'] if data.get('result') and len(data['result']) > 0 else '')" 2>/dev/null)

if [ -n "$EXISTING_RECORD_ID" ]; then
    echo "✓ Found existing record: $EXISTING_RECORD_ID"
    echo ""
    echo "Step 3: Updating existing DNS record..."

    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$EXISTING_RECORD_ID" \
        -H "$AUTH_HEADER" \
        $EXTRA_HEADER \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"CNAME\",\"name\":\"$SUBDOMAIN\",\"content\":\"$BACKEND_URL\",\"ttl\":1,\"proxied\":true}")

    SUCCESS=$(echo $UPDATE_RESPONSE | python3 -c "import sys, json; data=json.load(sys.stdin); print('true' if data.get('success') else 'false')" 2>/dev/null)

    if [ "$SUCCESS" = "true" ]; then
        echo "✓ DNS record updated successfully!"
    else
        echo "ERROR: Failed to update DNS record"
        echo "Response: $UPDATE_RESPONSE"
        exit 1
    fi
else
    echo "No existing record found"
    echo ""
    echo "Step 3: Creating new DNS record..."

    CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "$AUTH_HEADER" \
        $EXTRA_HEADER \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"CNAME\",\"name\":\"$SUBDOMAIN\",\"content\":\"$BACKEND_URL\",\"ttl\":1,\"proxied\":true}")

    SUCCESS=$(echo $CREATE_RESPONSE | python3 -c "import sys, json; data=json.load(sys.stdin); print('true' if data.get('success') else 'false')" 2>/dev/null)

    if [ "$SUCCESS" = "true" ]; then
        echo "✓ DNS record created successfully!"
    else
        echo "ERROR: Failed to create DNS record"
        echo "Response: $CREATE_RESPONSE"
        exit 1
    fi
fi

echo ""
echo "Step 4: Configuring SSL/TLS settings..."

SSL_RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/ssl" \
    -H "$AUTH_HEADER" \
    $EXTRA_HEADER \
    -H "Content-Type: application/json" \
    --data '{"value":"full"}')

SSL_SUCCESS=$(echo $SSL_RESPONSE | python3 -c "import sys, json; data=json.load(sys.stdin); print('true' if data.get('success') else 'false')" 2>/dev/null)

if [ "$SSL_SUCCESS" = "true" ]; then
    echo "✓ SSL/TLS set to Full"
else
    echo "⚠ Could not update SSL settings (may need to do manually)"
fi

echo ""
echo "========================================="
echo "Configuration Complete!"
echo "========================================="
echo ""
echo "DNS Record:"
echo "  Type: CNAME"
echo "  Name: $SUBDOMAIN"
echo "  Target: $BACKEND_URL"
echo "  Proxied: Yes (Cloudflare protection enabled)"
echo ""
echo "Next Steps:"
echo "1. Wait 1-5 minutes for DNS propagation"
echo "2. Test your endpoint:"
echo "   curl http://$FULL_DOMAIN/health"
echo ""
echo "3. Test from iOS app (it's already configured!)"
echo ""
