#!/bin/bash

# Configuration
GRAPH_NODE_URL="http://localhost:8020/"
SUBGRAPH_NAME="custom/subgraph"
IPFS_HASH="QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw"

echo "🚀 Starting indexing for $SUBGRAPH_NAME..."

# Create the subgraph in the node
echo "📦 Creating subgraph..."
curl -s -X POST $GRAPH_NODE_URL \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_create\",\"params\":{\"name\":\"$SUBGRAPH_NAME\"},\"id\":1}" | grep -q "error" && echo "⚠️ Subgraph might already exist or creation failed." || echo "✅ Subgraph created."

# Deploy the subgraph using the IPFS hash
echo "🚢 Deploying subgraph with hash: $IPFS_HASH..."
curl -s -X POST $GRAPH_NODE_URL \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"subgraph_deploy\",\"params\":{\"name\":\"$SUBGRAPH_NAME\",\"ipfs_hash\":\"$IPFS_HASH\"},\"id\":1}"

echo -e "\n✨ Deployment command sent. Check logs with: docker-compose logs -f graph-node"
