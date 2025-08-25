# 🎯 Langflow Integration Guide - The Missing Piece!

## Complete Setup: From Langflow to 90% Cost Savings

This guide shows **exactly** how to connect Langflow to LiteLLM for Anthropic prompt caching.

## 📊 The Complete Picture

```
Your Langflow Agent
       ↓
Custom LiteLLM Component (this guide!)
       ↓
LiteLLM Proxy (port 4000)
       ↓
Anthropic API (with caching)
       ↓
90% COST SAVINGS! 🎉
```

## 🚀 Step-by-Step Langflow Setup

### Step 1: Add Custom Component to Langflow

1. **Open Langflow** (http://localhost:7860)
2. **Go to**: Settings → Custom Components
3. **Click**: "New Custom Component"
4. **Paste**: The entire code from `litellm-component.py`
5. **Save**: Name it "LiteLLM Proxy"

### Step 2: Configure Your Flow

1. **Create new flow** or open existing
2. **Delete** existing LLM/Anthropic component
3. **Add**: Custom Components → LiteLLM Proxy
4. **Configure**:

```
Base URL: http://litellm-proxy:4000/v1  # If using Docker
         OR
         http://localhost:4000/v1       # If local

API Key: sk-litellm-master-2024

Model: claude-sonnet-4-cached           # For production (with cache)
       OR
       claude-opus-4-cached              # For more complex tasks
```

### Step 3: Connect Your Agent

#### For Chat/Agent Flows:
```
[System Prompt] → [LiteLLM Proxy] → [Chat Output]
```

#### For PDF Creator (KSOfferteTool):
```
[Input Fields] → [Prompt Template] → [LiteLLM Proxy] → [PDF Generator]
                        ↑
                 13,655 word prompt
                  (gets cached!)
```

## 🎨 Visual Guide in Langflow

### Before (Expensive):
```
┌─────────────────┐
│ Anthropic Claude│ ← Direct connection
│ $0.68 per call  │   NO caching
└─────────────────┘
```

### After (90% Cheaper):
```
┌─────────────────┐
│ LiteLLM Proxy   │ ← Custom component
│ $0.07 per call  │   WITH caching!
└─────────────────┘
```

## ⚙️ Component Settings Explained

### Base URL Options:

| Environment | URL | When to Use |
|------------|-----|-------------|
| **Docker Network** | `http://litellm-proxy:4000/v1` | Langflow in Docker |
| **Local Development** | `http://localhost:4000/v1` | Local testing |
| **Production** | `http://litellm-proxy:4000/v1` | Production setup |

### Model Selection:

| Model | Speed | Intelligence | Cost | Use Case |
|-------|-------|--------------|------|----------|
| **claude-sonnet-4-cached** | Fast ⚡ | Good | Lowest | PDF generation, standard queries |
| **claude-opus-4-cached** | Slower | Best 🧠 | Low | Complex analysis, creativity |

## 🔍 Verify It's Working

### 1. Check Langflow Logs:
```
🚀 Connecting to LiteLLM proxy at: http://litellm-proxy:4000/v1
📦 Using model: claude-sonnet-4-cached
✅ CACHE ENABLED - 90% cost savings active!
💰 Your 13,655 word prompt will be cached by Anthropic
```

### 2. Check LiteLLM Logs:
```bash
docker logs litellm-proxy --tail 20
# Should show: "cache_control injection successful"
```

### 3. Check Anthropic Console:
- Go to: https://console.anthropic.com/usage
- Look for: "Cache Read Tokens"
- Should be: ~45,000 tokens cached

## 🎯 Real Example: PDF Creator Integration

### Your Current Setup (Expensive):
```python
# In Langflow: KSOfferteTool_SIMPLIFIED_V6
Anthropic Component:
  Model: claude-3-sonnet
  System Prompt: [13,655 words]
  Cost: $0.68 per PDF
```

### New Setup (90% Cheaper):
```python
# Replace Anthropic with Custom Component
LiteLLM Proxy Component:
  Base URL: http://litellm-proxy:4000/v1
  API Key: sk-litellm-master-2024
  Model: claude-sonnet-4-cached
  System Prompt: [same 13,655 words]
  Cost: $0.07 per PDF (after first)
```

## 🔄 Development vs Production

### During Development (Testing Prompts):
```python
# Use nocache model to see changes immediately
Model: "claude-sonnet-4-nocache"  # Full price, no cache
```

### In Production (Cost Savings):
```python
# Use cached model for 90% savings
Model: "claude-sonnet-4-cached"    # Cached, cheap!
```

## ⚡ Performance Tips

### 1. Keep Cache Alive:
```bash
# Cache expires after 5 minutes idle
# Keep alive with periodic requests
while true; do
  curl -X POST http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer sk-litellm-master-2024" \
    -d '{"model":"claude-sonnet-4-cached","messages":[{"role":"system","content":"ping"}]}'
  sleep 240  # Every 4 minutes
done
```

### 2. Batch Similar Requests:
- Process multiple PDFs in sequence
- Cache stays warm between requests
- Maximum efficiency

### 3. Monitor Cache Hits:
```bash
# Watch cache performance
watch -n 10 'docker logs litellm-proxy --tail 5 | grep cache'
```

## 🚨 Troubleshooting Langflow Integration

### Component Not Showing:
1. Restart Langflow after adding component
2. Check component code for syntax errors
3. Verify imports are available

### Connection Refused:
```python
# Wrong (if in Docker):
base_url = "http://localhost:4000/v1"

# Correct (Docker network):
base_url = "http://litellm-proxy:4000/v1"
```

### No Cost Reduction:
1. Verify model name ends with `-cached`
2. Check LiteLLM logs for cache injection
3. Ensure system message is large (>1000 tokens)

## 📊 Cost Calculation

### Your Savings with PDF Creator:
```
Daily PDFs: 100
Cost without cache: 100 × $0.68 = $68/day
Cost with cache: 1 × $0.68 + 99 × $0.07 = $7.61/day

Daily savings: $60.39
Monthly savings: $1,811.70
Yearly savings: $22,042.35 💰
```

## 🎓 Key Insights

1. **Custom Component is the Bridge**: Without it, Langflow can't use LiteLLM
2. **Container Names Matter**: Use Docker network names, not localhost
3. **Model Names are Critical**: Must end with `-cached` for caching
4. **First Request Full Price**: Cache is created on first call
5. **Sliding Window**: Cache stays alive with use

## 📝 Checklist for Implementation

- [ ] LiteLLM proxy running (port 4000)
- [ ] Custom component added to Langflow
- [ ] Flow updated to use LiteLLM Proxy
- [ ] Base URL configured correctly
- [ ] Model name ends with `-cached`
- [ ] Test with small prompt first
- [ ] Verify cache hits in Anthropic Console
- [ ] Monitor cost reduction

## 🚀 Quick Copy-Paste Setup

### For Docker Setup:
```python
Base URL: http://litellm-proxy:4000/v1
API Key: sk-litellm-master-2024
Model: claude-sonnet-4-cached
```

### For Local Setup:
```python
Base URL: http://localhost:4000/v1
API Key: sk-litellm-master-2024
Model: claude-sonnet-4-cached
```

## 💡 Pro Tips

1. **Test Cache First**: Use a simple "Hello" prompt to verify caching works
2. **Monitor Continuously**: Keep LiteLLM logs open during testing
3. **Document Your Prompts**: Version control your system prompts
4. **Backup Before Changes**: Always export flows before modifications
5. **Use Both Models**: Development with nocache, production with cached

---

## 🎉 Success Metrics

When properly configured, you should see:
- ✅ 90% cost reduction
- ✅ 45,000+ tokens cached
- ✅ Response time under 3 seconds
- ✅ Sliding window keeping cache alive
- ✅ Happy accountant!

---

**This is it!** The complete picture from Langflow UI to 90% savings. No more missing pieces! 🚀