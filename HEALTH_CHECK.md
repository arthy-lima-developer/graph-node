# 🩺 Subgraph Health Check

Detect if a subgraph is **healthy**, **lagging**, or **unhealthy** with a single GraphQL call.

---

## How It Works

The health check queries the `_meta` field of any Graph Protocol subgraph:

```graphql
{
  _meta {
    hasIndexingErrors
    block {
      number
      timestamp
    }
  }
}
```

### Status Determination

| Condition | Status | Exit Code |
|-----------|--------|-----------|
| `hasIndexingErrors: true` | ❌ **UNHEALTHY** | 1 |
| Block timestamp > threshold behind | ⚠️ **LAGGING** | 1 |
| Block timestamp within threshold | ✅ **HEALTHY** | 0 |

**Default threshold:** 90 seconds

---

## Usage

### Basic Usage

```bash
./health-check.sh <GRAPHQL_ENDPOINT>
```

### Examples

```bash
# Check your AWS deployment
./health-check.sh https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v1

# Check The Graph Studio
./health-check.sh https://api.studio.thegraph.com/query/1718249/algebra-proposals-candles/version/latest

# Custom threshold (5 minutes)
THRESHOLD_SECONDS=300 ./health-check.sh https://your-endpoint.com/subgraphs/name/my-subgraph
```

### Sample Output

**Healthy:**
```
╔══════════════════════════════════════════════════════════════╗
║           SUBGRAPH HEALTH CHECK                              ║
╚══════════════════════════════════════════════════════════════╝

📡 Endpoint: https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v1
⏱️  Threshold: 90s

📊 Results:
   Block Number:    44287101
   Block Time:      2026-01-22 03:31:20
   Lag:             37s
   Indexing Errors: false

✅ STATUS: HEALTHY - Synced within 90s threshold
```

**Lagging:**
```
📊 Results:
   Block Number:    44282241
   Block Time:      2026-01-21 20:24:20
   Lag:             25541s
   Indexing Errors: false

⚠️  STATUS: LAGGING - 25541s behind (425 minutes)
```

---

## Integration Examples

### Bash Script Monitoring

```bash
#!/bin/bash
ENDPOINTS=(
    "https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v1"
    "https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/algebra-proposal-candles-v1"
)

for endpoint in "${ENDPOINTS[@]}"; do
    if ! ./health-check.sh "$endpoint"; then
        echo "ALERT: Subgraph unhealthy!"
        # Send notification here
    fi
done
```

### JavaScript/TypeScript

```typescript
async function checkSubgraphHealth(endpoint: string, thresholdSeconds = 90): Promise<{
  healthy: boolean;
  lag: number;
  blockNumber: number;
}> {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `{ _meta { hasIndexingErrors block { number timestamp } } }`
    })
  });

  const data = await response.json();
  const meta = data.data._meta;
  
  const now = Math.floor(Date.now() / 1000);
  const lag = now - meta.block.timestamp;
  
  return {
    healthy: !meta.hasIndexingErrors && lag <= thresholdSeconds,
    lag,
    blockNumber: meta.block.number
  };
}

// Usage
const health = await checkSubgraphHealth('https://your-endpoint.com/subgraphs/name/my-subgraph');
if (!health.healthy) {
  console.log(`Subgraph lagging by ${health.lag} seconds`);
}
```

### Python

```python
import requests
import time

def check_subgraph_health(endpoint: str, threshold_seconds: int = 90) -> dict:
    query = '{ _meta { hasIndexingErrors block { number timestamp } } }'
    response = requests.post(endpoint, json={'query': query})
    data = response.json()['data']['_meta']
    
    now = int(time.time())
    lag = now - data['block']['timestamp']
    
    return {
        'healthy': not data['hasIndexingErrors'] and lag <= threshold_seconds,
        'lag': lag,
        'block_number': data['block']['number']
    }
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Healthy |
| 1 | Lagging or has errors |
| 2 | Connection/query error |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `THRESHOLD_SECONDS` | 90 | Maximum acceptable lag in seconds |
