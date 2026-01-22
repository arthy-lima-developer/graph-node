#!/bin/bash
#
# Graph Node Subgraph Health Check
# Checks if a subgraph is synced and not lagging behind chain head
#

# Configuration
THRESHOLD_SECONDS=${THRESHOLD_SECONDS:-90}  # Default 90 seconds

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <GRAPHQL_ENDPOINT>"
    echo ""
    echo "Examples:"
    echo "  $0 https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/futarchy-complete-new-v1"
    echo "  $0 https://api.studio.thegraph.com/query/1718249/algebra-proposals-candles/version/latest"
    echo ""
    echo "Environment variables:"
    echo "  THRESHOLD_SECONDS  - Lag threshold in seconds (default: 90)"
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

ENDPOINT="$1"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SUBGRAPH HEALTH CHECK                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📡 Endpoint: $ENDPOINT"
echo "⏱️  Threshold: ${THRESHOLD_SECONDS}s"
echo ""

# Query the subgraph
RESPONSE=$(curl -s "$ENDPOINT" \
    -H 'Content-Type: application/json' \
    -d '{"query":"{ _meta { hasIndexingErrors block { number timestamp } } }"}' 2>/dev/null)

# Check if curl succeeded
if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo -e "${RED}❌ ERROR: Failed to connect to endpoint${NC}"
    exit 2
fi

# Check for GraphQL errors
ERROR=$(echo "$RESPONSE" | grep -o '"errors"' 2>/dev/null)
if [ -n "$ERROR" ]; then
    echo -e "${RED}❌ ERROR: GraphQL query failed${NC}"
    echo "$RESPONSE" | jq '.errors' 2>/dev/null || echo "$RESPONSE"
    exit 2
fi

# Parse response
HAS_ERRORS=$(echo "$RESPONSE" | jq -r '.data._meta.hasIndexingErrors' 2>/dev/null)
BLOCK_NUMBER=$(echo "$RESPONSE" | jq -r '.data._meta.block.number' 2>/dev/null)
BLOCK_TIMESTAMP=$(echo "$RESPONSE" | jq -r '.data._meta.block.timestamp' 2>/dev/null)

# Validate response
if [ "$BLOCK_TIMESTAMP" = "null" ] || [ -z "$BLOCK_TIMESTAMP" ]; then
    echo -e "${RED}❌ ERROR: Could not parse block timestamp${NC}"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    exit 2
fi

# Calculate lag
NOW=$(date +%s)
LAG=$((NOW - BLOCK_TIMESTAMP))
BLOCK_TIME=$(date -d "@$BLOCK_TIMESTAMP" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$BLOCK_TIMESTAMP" '+%Y-%m-%d %H:%M:%S')

echo "📊 Results:"
echo "   Block Number:    $BLOCK_NUMBER"
echo "   Block Time:      $BLOCK_TIME"
echo "   Lag:             ${LAG}s"
echo "   Indexing Errors: $HAS_ERRORS"
echo ""

# Determine status
if [ "$HAS_ERRORS" = "true" ]; then
    echo -e "${RED}❌ STATUS: UNHEALTHY - Has indexing errors${NC}"
    exit 1
elif [ "$LAG" -gt "$THRESHOLD_SECONDS" ]; then
    LAG_MINUTES=$((LAG / 60))
    echo -e "${YELLOW}⚠️  STATUS: LAGGING - ${LAG}s behind (${LAG_MINUTES} minutes)${NC}"
    exit 1
else
    echo -e "${GREEN}✅ STATUS: HEALTHY - Synced within ${THRESHOLD_SECONDS}s threshold${NC}"
    exit 0
fi
