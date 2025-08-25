# 📚 10+ Hours of Debugging - Complete Lessons Learned

## The Journey: From $0.98 to $0.07 per Request

This document chronicles our complete debugging journey implementing Anthropic's prompt caching with LiteLLM proxy. What should have been a 1-hour task became a 10+ hour learning experience.

## 🕐 Timeline of Attempts

### Hour 1-2: Direct Anthropic Component Modification
**What we tried:**
- Modified Langflow's Anthropic component directly
- Added cache_control headers manually
- Tried environment variables

**Why it failed:**
- Langflow's component doesn't expose cache_control
- Headers were being stripped
- No way to inject cache metadata

**Lesson:** Don't modify vendor components - use middleware!

### Hour 3-4: Environment Variable Attempts
**What we tried:**
```python
os.environ['ANTHROPIC_CACHE_ENABLED'] = 'true'
os.environ['ANTHROPIC_CACHE_TTL'] = '3600'
```

**Why it failed:**
- These environment variables don't exist
- Anthropic SDK doesn't read cache config from env
- Cache must be set per message, not globally

**Lesson:** Cache control is message-level, not client-level

### Hour 5-6: LiteLLM Initial Setup
**What we tried:**
- Basic LiteLLM proxy setup
- Simple pass-through configuration
- Expected automatic caching

**Why it failed:**
```yaml
# This doesn't work - too simple
model_list:
  - model_name: claude
    litellm_params:
      model: anthropic/claude-sonnet-4
```

**Lesson:** LiteLLM needs explicit cache injection config

### Hour 7-8: The Localhost Trap
**What we tried:**
```python
# In Langflow component
base_url = "http://localhost:4000/v1"
```

**Why it failed:**
- Langflow runs in Docker container
- localhost inside container ≠ host localhost
- Connection refused errors

**The fix:**
```python
base_url = "http://litellm-proxy:4000/v1"  # Container name!
```

**Lesson:** Always use container names in Docker networks

### Hour 9: The TTL Parameter Disaster
**What we tried:**
```yaml
cache_control_injection_points:
  - location: message
    role: system
    type: ephemeral
    ttl: 3600  # ← THIS BROKE EVERYTHING
```

**What happened:**
- Cache completely stopped working
- 0 tokens cached
- Cost went back to $0.98

**The fix:**
```yaml
cache_control_injection_points:
  - location: message
    role: system
    type: ephemeral
    # NO TTL! Uses Anthropic's default 5-min sliding window
```

**Lesson:** LiteLLM's TTL parameter is incompatible with Anthropic's implementation

### Hour 10: The Breakthrough
**What finally worked:**
1. Simple cache injection without TTL
2. Container networking properly configured
3. Separate cached/nocache models for development
4. Monitoring via Anthropic Console

**Result:** 45,205 tokens cached, 90% cost reduction!

## 🎯 Key Discoveries

### Discovery 1: Sliding Window Magic
The 5-minute TTL is a **sliding window**:
- Each cache hit resets the timer
- Cache can live forever with regular use
- No need to manage cache lifecycle

### Discovery 2: Development vs Production Models
Having two models is essential:
```yaml
claude-sonnet-4-cached    # Production - with caching
claude-sonnet-4-nocache   # Development - see changes immediately
```

### Discovery 3: Cache Injection Points
The cache is injected at the message level:
```yaml
cache_control_injection_points:
  - location: message    # Where to inject
    role: system        # Which message role
    type: ephemeral     # Cache type
```

## ❌ Complete List of What Doesn't Work

1. **TTL Parameter in LiteLLM**
   - Breaks cache completely
   - Not compatible with Anthropic's implementation

2. **Localhost URLs in Containers**
   - Use container names instead
   - Docker networking 101

3. **Environment Variables for Caching**
   - Cache is message-level, not global
   - Must use proper API structure

4. **Manual Header Injection**
   ```python
   # This doesn't work
   headers = {"anthropic-beta": "prompt-caching-2024-07-31"}
   ```
   - Headers alone aren't enough
   - Need proper cache_control in message

5. **Modifying Vendor Components**
   - Langflow components are sealed
   - Use middleware proxy instead

6. **Assuming Automatic Caching**
   - Caching must be explicitly configured
   - No magic defaults

## ✅ Complete List of What Works

1. **LiteLLM as Middleware Proxy**
   - Handles cache injection
   - Transparent to Langflow

2. **Simple Cache Config (No TTL)**
   ```yaml
   cache_control_injection_points:
     - location: message
       role: system
       type: ephemeral
   ```

3. **Container Networking**
   ```python
   base_url = "http://litellm-proxy:4000/v1"
   ```

4. **Dual Model Strategy**
   - cached for production
   - nocache for development

5. **Anthropic Console Monitoring**
   - Real-time cache hit verification
   - Cost tracking

## 🔬 Technical Deep Dive

### How Cache Injection Actually Works

1. **Request Flow:**
```
Langflow → LiteLLM → Anthropic
         ↓
   Injects cache_control
```

2. **What LiteLLM Adds:**
```json
{
  "messages": [
    {
      "role": "system",
      "content": "Your 13,655 word prompt...",
      "cache_control": {  // ← LiteLLM adds this
        "type": "ephemeral"
      }
    }
  ]
}
```

3. **Anthropic's Response:**
```json
{
  "usage": {
    "input_tokens": 45205,
    "cache_creation_input_tokens": 45205,  // First request
    "cache_read_input_tokens": 45205,      // Subsequent requests
    "output_tokens": 2000
  }
}
```

### Why TTL Parameter Breaks

LiteLLM's TTL implementation conflicts with Anthropic's:
- LiteLLM tries to set: `"cache_control": {"type": "ephemeral", "ttl": 3600}`
- Anthropic expects: `"cache_control": {"type": "ephemeral"}`
- The extra TTL field causes Anthropic to reject the cache

## 🚨 Warning Signs You're Doing It Wrong

1. **Zero Cache Hits After Multiple Requests**
   - Check your config doesn't have TTL
   - Verify cache_control is being injected

2. **Connection Refused Errors**
   - You're using localhost in containers
   - Switch to container names

3. **Cost Not Decreasing**
   - Cache isn't working
   - Check Anthropic Console

4. **First Request is Cheap**
   - You're hitting old cache
   - Your prompt hasn't changed

## 💡 Pro Tips

### Tip 1: Monitor Everything
```bash
# Three terminals:
# Terminal 1: LiteLLM logs
docker logs -f litellm-proxy

# Terminal 2: Langflow logs
docker logs -f langflow-production

# Terminal 3: Cost monitor
watch -n 60 'curl -s https://console.anthropic.com/api/usage | jq .today'
```

### Tip 2: Test Cache Before Production
```bash
# Quick cache test
for i in {1..5}; do
  echo "Request $i:"
  time curl -X POST http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer sk-litellm-master-2024" \
    -d '{"model":"claude-sonnet-4-cached","messages":[...]}'
  sleep 10
done
```

### Tip 3: Keep Configurations Versioned
```bash
# Always backup working configs
cp litellm-config.yaml litellm-config-$(date +%Y%m%d-%H%M%S).yaml
git add litellm-config.yaml
git commit -m "Working cache config - 90% savings"
```

## 🎓 Final Wisdom

After 10+ hours, here's what we know for certain:

1. **Simpler is better** - Minimal config that works > complex config that doesn't
2. **Trust the defaults** - Anthropic's 5-minute sliding window is perfect
3. **Monitor religiously** - You can't optimize what you don't measure
4. **Separate dev/prod** - cached vs nocache models save debugging time
5. **Document everything** - Your future self will thank you

## 📈 The Numbers That Matter

- **Time invested**: 10+ hours
- **Knowledge gained**: Priceless
- **Cost reduction**: 90%
- **Monthly savings**: $1,815
- **ROI on debugging time": 180,000%

## 🙏 Acknowledgments

This solution wouldn't exist without:
- Multiple failed attempts that taught us what NOT to do
- The realization that TTL breaks everything
- Understanding Docker networking (finally!)
- The Anthropic Console for verification
- Coffee. Lots of coffee.

---

**Remember**: Every failed attempt taught us something. The 10 hours weren't wasted - they were invested in understanding.

**Final thought**: "But there we have the LiteLLM proxy for that, right? I don't understand." - This question at hour 3 was the turning point. Yes, we did have LiteLLM for that. We just needed 7 more hours to figure out HOW to use it correctly!

🚀 Now you can do it in 30 minutes with our guide!