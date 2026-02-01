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
# Check your AWS deployment (use v3 - latest with null-safety fix)
./health-check.sh https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v3

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

📡 Endpoint: https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v3
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
    "https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v3"
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

---

## 📡 Deployed Endpoints (AWS)

### CloudFront (HTTPS - Production)

| Subgraph | Status | Endpoint |
|----------|--------|----------|
| `futarchy-complete-new-v3` | ✅ **RECOMMENDED** | `https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v3` |
| `futarchy-complete-new-v1` | ✅ Healthy | `https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v1` |
| `algebra-proposal-candles-v1` | ✅ Healthy | `https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/algebra-proposal-candles-v1` |
| `futarchy-complete-new-v2` | ❌ Failed | `https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v2` |

### The Graph Studio

| Subgraph | Endpoint |
|----------|----------|
| `futarchy-complete-new` (v0.0.15) | `https://api.studio.thegraph.com/query/1719045/futarchy-complete-new/0.0.15` |

### Direct EC2 Access (HTTP)

```bash
# GraphQL Queries
http://34.195.104.118:8000/subgraphs/name/<SUBGRAPH_NAME>

# Indexing Status
http://34.195.104.118:8030/graphql

# JSON-RPC Deploy
http://34.195.104.118:8020/
```

---

## 🔧 Troubleshooting: v2 → v3 Migration

### Problem: v2 Failed at Block 44,463,012

**Error:**
```
Mapping aborted at src/mapping.ts, line 177, column 45, 
with message: unexpected null in handler `handleOrganizationCreatedAndAdded`
```

**Root Cause:**
The `CoW DAO` organization was created with `null` metadata. The mapping code used:
```typescript
entity.metadataProperties = extractKeys(entity.metadata as string)
```
This crashed when `entity.metadata` was `null` because AssemblyScript's `as string` cast doesn't handle nulls.

**Transaction that triggered it:**
- TX: `0x44fecb7bc03d767cab0cf78a0c4cab7ea8a5c26be372d31740f9ed675aa79721`
- Block: `44,463,012` (Gnosis Chain)
- Method: `createAndAddOrganizationMetadata("CoW DAO", ...)`

### Solution: v3 Fix

Fixed all 8 instances in `futarchy-complete/src/mapping.ts`:

```typescript
// Before (crashes on null):
entity.metadataProperties = extractKeys(entity.metadata as string)

// After (null-safe):
entity.metadataProperties = extractKeys(
  entity.metadata !== null ? changetype<string>(entity.metadata) : ""
)
```

**Affected Handlers:**
- `handleAggregatorCreated` (line 50)
- `handleOrganizationMetadataCreated` (line 77)
- `handleProposalMetadataCreated` (line 118)
- `handleOrganizationCreatedAndAdded` (line 177) ← **The failure point**
- `handleAggregatorExtendedMetadataUpdated` (line 196)
- `handleProposalCreatedAndAdded` (line 268)
- `handleOrganizationExtendedMetadataUpdated` (line 293)
- `handleProposalExtendedMetadataUpdated` (line 343)

### Deployment

```bash
# Deployed v3 to AWS Graph Node
ssh -i graph-node-key.pem ubuntu@34.195.104.118 \
  "cd graph-node && ./deploy.sh futarchy-complete-new-v3 QmTvu7WaFnXNfq8jjsPUtLWwsnzWRj2p9B3pWeaFnM7x3z"

# Deployed to The Graph Studio
npx graph deploy --node https://api.studio.thegraph.com/deploy/ \
  --deploy-key <KEY> futarchy-complete-new --version-label 0.0.15
```

### Verification

```bash
# Check v3 health on CloudFront
curl -s "https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v3" \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ _meta { block { number } hasIndexingErrors } }"}'

# Check all subgraphs status
curl -s "http://34.195.104.118:8030/graphql" \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ indexingStatuses { subgraph synced health } }"}'
```
