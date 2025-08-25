# 🔧 Troubleshooting Guide

## Common Issues and Solutions

### 🔴 Issue: No Cache Hits Despite Multiple Requests

**Symptoms:**
- Anthropic Console shows 0 "Cache Read Tokens"
- Every request costs full price
- No cache-related logs in LiteLLM

**Solution 1: Verify Config**
```bash
# Check if cache_control_injection is configured
docker exec litellm-proxy cat /litellm/config.yaml | grep -A5 cache_control
```

**Solution 2: Remove TTL Parameter**
```yaml
# WRONG - This breaks caching
cache_control_injection_points:
  - location: message
    role: system
    type: ephemeral
    ttl: 3600  # ← REMOVE THIS LINE!

# CORRECT
cache_control_injection_points:
  - location: message
    role: system
    type: ephemeral
```

**Solution 3: Check Model Name**
```python
# Ensure you're using the cached model
model = "claude-sonnet-4-cached"  # NOT "claude-sonnet-4"
```

---

### 🔴 Issue: Connection Refused from Langflow

**Symptoms:**
```
ConnectionError: HTTPConnectionPool(host='localhost', port=4000): Connection refused
```

**Solution: Use Container Name**
```python
# WRONG
base_url = "http://localhost:4000/v1"

# CORRECT
base_url = "http://litellm-proxy:4000/v1"
```

**Verify Network:**
```bash
# Check both containers are on same network
docker network inspect langflow-network
```

---

### 🔴 Issue: Authentication Failed

**Symptoms:**
```
Error: Invalid API key
```

**Solution 1: Check Master Key**
```python
api_key = "sk-litellm-master-2024"  # Must match config
```

**Solution 2: Verify Anthropic Key**
```bash
# Test Anthropic key directly
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d '{"model":"claude-3-sonnet-20240229","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}'
```

---

### 🔴 Issue: Cache Expires After 5 Minutes

**Symptoms:**
- First request: cache hit
- Request after 6 minutes: cache miss

**Solution: This is Normal!**
- Cache has 5-minute sliding window
- Each hit resets the timer
- Keep requests within 5-minute intervals

**Workaround for Development:**
```bash
# Keep cache alive during development
while true; do
  curl -X POST http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer sk-litellm-master-2024" \
    -d '{"model":"claude-sonnet-4-cached","messages":[{"role":"system","content":"..."}]}' \
    > /dev/null 2>&1
  sleep 240  # 4 minutes
done
```

---

### 🔴 Issue: Docker Container Won't Start

**Symptoms:**
```
Error: yaml: line 10: found character that cannot start any token
```

**Solution: Fix YAML Formatting**
```yaml
# Check for tabs (use spaces only)
sed -i 's/\t/  /g' litellm-config.yaml

# Validate YAML
python -c "import yaml; yaml.safe_load(open('litellm-config.yaml'))"
```

---

### 🔴 Issue: Costs Not Decreasing

**Symptoms:**
- Cache seems to work
- But costs remain high

**Diagnosis:**
```bash
# Check cache effectiveness
curl -s https://console.anthropic.com/api/usage | jq '
  .today | {
    total_tokens: .total_tokens,
    cached_tokens: .cache_read_tokens,
    cache_percentage: (.cache_read_tokens / .total_tokens * 100)
  }'
```

**Solution: Verify System Message**
- Cache only works on system messages
- User messages are never cached
- Ensure your large prompt is in system role

---

### 🔴 Issue: Different Results with Cache

**Symptoms:**
- Cached responses differ from non-cached

**Solution: This is a Misconception**
- Cache only affects the prompt, not the response
- Responses are always generated fresh
- Temperature/randomness still applies

---

## 🛠️ Diagnostic Commands

### Check Everything at Once
```bash
#!/bin/bash
echo "=== LiteLLM Status ==="
docker ps | grep litellm

echo -e "\n=== Config Verification ==="
docker exec litellm-proxy cat /litellm/config.yaml | grep -E "model_name|cache_control" 

echo -e "\n=== Recent Logs ==="
docker logs litellm-proxy --tail 10 | grep -E "cache|Cache|ERROR"

echo -e "\n=== Network Check ==="
docker exec langflow-production ping -c 1 litellm-proxy

echo -e "\n=== API Test ==="
curl -s http://localhost:4000/health

echo -e "\n=== Cache Test Request ==="
time curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-litellm-master-2024" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-cached",
    "messages": [
      {"role": "system", "content": "Test cache"},
      {"role": "user", "content": "Say OK"}
    ]
  }' | jq .choices[0].message.content
```

### Monitor Cache Performance
```bash
# Real-time cache monitoring
watch -n 5 'docker logs litellm-proxy --tail 20 | grep cache'
```

### Force Cache Reset
```bash
# Restart LiteLLM to clear any stuck states
docker restart litellm-proxy

# Wait for health
sleep 10

# Test fresh cache
./tests/test-cache.sh
```

---

## 🚨 Emergency Procedures

### Complete Reset
```bash
# 1. Stop everything
docker stop litellm-proxy langflow-production

# 2. Clear any corrupted state
docker rm litellm-proxy langflow-production

# 3. Restart with fresh config
docker-compose up -d

# 4. Verify
docker logs litellm-proxy --tail 50
```

### Fallback to No-Cache
```python
# In emergency, switch to non-cached model
model = "claude-sonnet-4-nocache"  # Full price but always works
```

### Debug Mode
```yaml
# Enable maximum logging in config
litellm_settings:
  set_verbose: true
  json_logs: true
  log_raw_request_response: true  # Warning: logs sensitive data
```

---

## 📞 When All Else Fails

1. **Check Anthropic Status**: https://status.anthropic.com
2. **Verify API Key**: Try key directly with Anthropic API
3. **Review Our Journey**: Read [LESSONS-LEARNED.md](./LESSONS-LEARNED.md)
4. **Start Fresh**: Use known-working config from this repo

Remember: We spent 10+ hours debugging this. Every issue here was encountered and solved. The solution is always simpler than you think!