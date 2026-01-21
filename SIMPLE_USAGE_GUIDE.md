# 📖 Simple Usage Guide

## Quick Start

### 1. Start Services
```bash
docker compose up -d
```

### 2. Deploy a Subgraph (One Command!)
```bash
./deploy.sh <name> <ipfs-hash>
```

**Example:**
```bash
./deploy.sh futarchy-complete-new QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw
```

The script automatically:
- ✅ Fetches all IPFS dependencies from public gateway  
- ✅ Pins them to local IPFS node
- ✅ Creates and deploys the subgraph
- ✅ Waits for indexing to start
- ✅ Runs a test query to verify

---

## Query Your Subgraph

**GraphQL Endpoint:**
```
http://localhost:8000/subgraphs/name/<your-subgraph-name>
```

**Example Query:**
```bash
curl http://localhost:8000/subgraphs/name/futarchy-complete-new \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ _meta { block { number } } }"}'
```

---

## Check Status

```bash
# View logs
./logs.sh

# Check indexing status
curl http://localhost:8030/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ indexingStatuses { subgraph synced health } }"}'
```

---

## Stop Everything
```bash
docker compose down
```

## Reset (Delete All Data)
```bash
docker compose down -v
rm -rf postgres-data ipfs-data
```
