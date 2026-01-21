#!/bin/bash

# Configuration with defaults
GRAPH_NODE_URL="http://localhost:8020/"
SUBGRAPH_NAME="${1:-futarchy-complete-new}"
IPFS_HASH="${2:-QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw}"

echo "🚀 Starting indexing for $SUBGRAPH_NAME..."
echo "📍 IPFS Hash: $IPFS_HASH"

# Create the subgraph in the node
echo "📦 Creating subgraph..."
CREATE_RESULT=$(curl -s -X POST $GRAPH_NODE_URL \
  -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_create\",\"params\":{\"name\":\"$SUBGRAPH_NAME\"},\"id\":1}")

if echo "$CREATE_RESULT" | grep -q "error"; then
    echo "⚠️ Subgraph might already exist or creation failed. Result: $CREATE_RESULT"
else
    echo "✅ Subgraph created."
fi

# Deploy the subgraph using the IPFS hash
echo "🚢 Deploying subgraph..."
DEPLOY_RESULT=$(curl -s -X POST $GRAPH_NODE_URL \
  -H 'Content-Type: application/json' \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_deploy\",\"params\":{\"name\":\"$SUBGRAPH_NAME\",\"ipfs_hash\":\"$IPFS_HASH\"},\"id\":1}")

if echo "$DEPLOY_RESULT" | grep -q "error"; then
    echo "❌ Deployment failed: $DEPLOY_RESULT"
else
    echo "✅ Deployment command sent successfully."
    echo -e "\n📊 Query Endpoint: http://localhost:8000/subgraphs/name/$SUBGRAPH_NAME"
    echo "🔍 GraphiQL: http://localhost:8000/subgraphs/name/$SUBGRAPH_NAME/graphql"
fi

echo -e "\n✨ Check logs with: ./logs.sh"
