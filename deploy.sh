#!/bin/bash
set -e

# ============================================================================
# GRAPH NODE SUBGRAPH DEPLOYER
# One-command deployment: fetches IPFS deps, deploys, verifies, and tests
# ============================================================================

SUBGRAPH_NAME="${1:-futarchy-complete-new}"
IPFS_HASH="${2:-QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw}"
GRAPH_NODE_URL="http://localhost:8020/"
QUERY_URL="http://localhost:8000/subgraphs/name/$SUBGRAPH_NAME"
STATUS_URL="http://localhost:8030/graphql"
GATEWAY="https://ipfs.io/ipfs"
IPFS_STAGING="./ipfs-data/staging"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           GRAPH NODE SUBGRAPH DEPLOYER                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📦 Subgraph: $SUBGRAPH_NAME"
echo "🔗 IPFS Hash: $IPFS_HASH"
echo ""

# ────────────────────────────────────────────────────────────────────
# STEP 1: Verify services are running
# ────────────────────────────────────────────────────────────────────
echo "🔍 Step 1: Checking services..."
if ! docker compose ps --status running | grep -q "graph-node"; then
  echo "⚠️  Graph Node not running. Starting services..."
  docker compose up -d
  sleep 10
fi
echo "   ✅ Services running"

# ────────────────────────────────────────────────────────────────────
# STEP 2: Fetch manifest and extract all IPFS dependencies
# ────────────────────────────────────────────────────────────────────
echo ""
echo "📥 Step 2: Fetching IPFS dependencies..."
mkdir -p "$IPFS_STAGING"

# Fetch the manifest first
MANIFEST_FILE="$IPFS_STAGING/$IPFS_HASH"
echo "   Fetching manifest $IPFS_HASH..."
curl -sL --max-time 60 -o "$MANIFEST_FILE" "$GATEWAY/$IPFS_HASH"

if [ ! -s "$MANIFEST_FILE" ]; then
  echo "   ❌ Failed to fetch manifest from IPFS gateway"
  exit 1
fi

# Add manifest to local IPFS
docker compose exec -T ipfs ipfs add -q --pin=true "/data/ipfs/staging/$IPFS_HASH" > /dev/null 2>&1
echo "   ✅ Manifest pinned"

# Extract all Qm hashes from manifest
DEPS=$(grep -oP 'Qm[a-zA-Z0-9]{44}' "$MANIFEST_FILE" | sort -u)
DEP_COUNT=$(echo "$DEPS" | wc -l)
echo "   Found $DEP_COUNT dependencies to fetch..."

for dep in $DEPS; do
  DEP_FILE="$IPFS_STAGING/$dep"
  echo -n "   📡 $dep... "
  
  if curl -sL --max-time 60 -o "$DEP_FILE" "$GATEWAY/$dep" 2>/dev/null && [ -s "$DEP_FILE" ]; then
    ADDED=$(docker compose exec -T ipfs ipfs add -q --pin=true "/data/ipfs/staging/$dep" 2>/dev/null)
    if [ "$ADDED" = "$dep" ]; then
      echo "✅"
    else
      echo "⚠️ (pinned as $ADDED)"
    fi
  else
    echo "❌ (download failed)"
  fi
done

# ────────────────────────────────────────────────────────────────────
# STEP 3: Create and deploy subgraph
# ────────────────────────────────────────────────────────────────────
echo ""
echo "🚀 Step 3: Deploying subgraph..."

# Create
curl -s -X POST "$GRAPH_NODE_URL" \
  -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_create\",\"params\":{\"name\":\"$SUBGRAPH_NAME\"},\"id\":1}" > /dev/null

# Deploy
DEPLOY_RESULT=$(curl -s -X POST "$GRAPH_NODE_URL" \
  -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_deploy\",\"params\":{\"name\":\"$SUBGRAPH_NAME\",\"ipfs_hash\":\"$IPFS_HASH\"},\"id\":1}")

if echo "$DEPLOY_RESULT" | grep -q "error"; then
  echo "   ❌ Deployment failed: $DEPLOY_RESULT"
  exit 1
fi
echo "   ✅ Deployment submitted"

# ────────────────────────────────────────────────────────────────────
# STEP 4: Wait for indexing to start
# ────────────────────────────────────────────────────────────────────
echo ""
echo "⏳ Step 4: Waiting for indexing to start..."
for i in {1..30}; do
  STATUS=$(curl -s "$STATUS_URL" -H 'Content-Type: application/json' \
    -d '{"query":"{ indexingStatuses { subgraph synced health } }"}')
  
  if echo "$STATUS" | grep -q "$IPFS_HASH"; then
    echo "   ✅ Indexing started!"
    break
  fi
  
  echo -n "."
  sleep 2
done
echo ""

# ────────────────────────────────────────────────────────────────────
# STEP 5: Check status and run test query
# ────────────────────────────────────────────────────────────────────
echo "📊 Step 5: Checking status..."
STATUS=$(curl -s "$STATUS_URL" -H 'Content-Type: application/json' \
  -d "{\"query\":\"{ indexingStatuses(subgraphs: [\\\"$IPFS_HASH\\\"]) { synced health fatalError { message } chains { network latestBlock { number } chainHeadBlock { number } } } }\"}")

echo "$STATUS" | jq -r '.data.indexingStatuses[0] | "   Health: \(.health)\n   Synced: \(.synced)\n   Block: \(.chains[0].latestBlock.number // "pending")"' 2>/dev/null || echo "   Status: Starting up..."

echo ""
echo "🧪 Step 6: Running test query..."
TEST=$(curl -s "$QUERY_URL" -H 'Content-Type: application/json' \
  -d '{"query":"{ _meta { block { number } hasIndexingErrors } }"}' 2>/dev/null)

if echo "$TEST" | grep -q "block"; then
  BLOCK=$(echo "$TEST" | jq -r '.data._meta.block.number')
  ERRORS=$(echo "$TEST" | jq -r '.data._meta.hasIndexingErrors')
  echo "   ✅ Query successful!"
  echo "   Block: $BLOCK"
  echo "   Errors: $ERRORS"
else
  echo "   ⏳ Subgraph still syncing, try again in a moment"
fi

# ────────────────────────────────────────────────────────────────────
# DONE
# ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      DEPLOYMENT COMPLETE                     ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Query:    $QUERY_URL"
echo "║  GraphiQL: ${QUERY_URL}/graphql"
echo "║  Logs:     ./logs.sh"
echo "╚══════════════════════════════════════════════════════════════╝"
