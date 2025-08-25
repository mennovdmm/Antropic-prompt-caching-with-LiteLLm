#!/bin/bash

# Anthropic Cache Testing Script
# Tests if caching is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
API_KEY="${API_KEY:-sk-litellm-master-2024}"
MODEL="${MODEL:-claude-sonnet-4-cached}"

echo "🧪 Anthropic Cache Testing Script"
echo "=================================="
echo "LiteLLM URL: $LITELLM_URL"
echo "Model: $MODEL"
echo ""

# Function to make a request and extract cache info
make_request() {
    local request_num=$1
    echo -e "${YELLOW}Request #$request_num:${NC}"
    
    # Create a large system prompt (simulating real use case)
    SYSTEM_PROMPT="You are a helpful assistant. This is a long system prompt for testing cache functionality. $(head -c 10000 < /dev/zero | tr '\0' 'a')"
    
    # Make the request and capture response
    RESPONSE=$(curl -s -X POST "$LITELLM_URL/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{
            \"model\": \"$MODEL\",
            \"messages\": [
                {\"role\": \"system\", \"content\": \"$SYSTEM_PROMPT\"},
                {\"role\": \"user\", \"content\": \"Say 'Cache test $request_num successful'\"}
            ]
        }")
    
    # Check if request was successful
    if echo "$RESPONSE" | grep -q "Cache test $request_num successful"; then
        echo -e "${GREEN}✓ Request successful${NC}"
    else
        echo -e "${RED}✗ Request failed${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi
    
    # Extract token usage if available
    if echo "$RESPONSE" | grep -q "usage"; then
        echo "$RESPONSE" | grep -o '"usage":[^}]*}' || true
    fi
    
    echo ""
}

# Function to check LiteLLM logs for cache activity
check_cache_logs() {
    echo -e "${YELLOW}Checking LiteLLM logs for cache activity:${NC}"
    docker logs litellm-proxy --tail 20 | grep -i cache || echo "No cache logs found"
    echo ""
}

# Test 1: Verify LiteLLM is running
echo "Test 1: Checking LiteLLM availability..."
if curl -s "$LITELLM_URL/health" > /dev/null; then
    echo -e "${GREEN}✓ LiteLLM is running${NC}"
else
    echo -e "${RED}✗ LiteLLM is not accessible at $LITELLM_URL${NC}"
    exit 1
fi
echo ""

# Test 2: Make multiple requests to test caching
echo "Test 2: Making multiple requests to test cache..."
echo "First request should create cache, subsequent should hit cache"
echo ""

for i in {1..3}; do
    make_request $i
    
    if [ $i -eq 1 ]; then
        echo "⏳ Waiting 10 seconds before next request..."
        sleep 10
    else
        echo "⏳ Waiting 5 seconds before next request..."
        sleep 5
    fi
done

# Test 3: Check cache logs
echo "Test 3: Analyzing cache behavior..."
check_cache_logs

# Test 4: Test nocache model (if configured)
echo "Test 4: Testing nocache model (optional)..."
RESPONSE=$(curl -s -X POST "$LITELLM_URL/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "{
        \"model\": \"claude-sonnet-4-nocache\",
        \"messages\": [
            {\"role\": \"user\", \"content\": \"Test nocache model\"}
        ]
    }" 2>/dev/null)

if echo "$RESPONSE" | grep -q "error"; then
    echo -e "${YELLOW}ℹ nocache model not configured (this is optional)${NC}"
else
    echo -e "${GREEN}✓ nocache model is available for development${NC}"
fi
echo ""

# Summary
echo "=================================="
echo "🎯 Cache Test Summary"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Check Anthropic Console for cache hits: https://console.anthropic.com/usage"
echo "2. Look for 'Cache Read Tokens' in today's usage"
echo "3. If you see cache hits, you're saving 90% on costs!"
echo ""
echo -e "${GREEN}✨ Test complete!${NC}"
echo ""
echo "💡 Tip: Run this script multiple times to verify sliding window behavior"
echo "   The cache should stay alive as long as requests are within 5 minutes"