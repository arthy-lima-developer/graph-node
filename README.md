# Graph Node - Private Indexer

Custom Graph Node setup for indexing subgraphs on Gnosis Chain.

## Subgraph Info
- **IPFS Hash:** `QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw`
- **Network:** Gnosis Chain
- **RPC:** `https://rpc.gnosischain.com`

## Usage Guide

### 1. Prerequisites
- Docker and Docker Compose installed.
- Logged into GitHub via `gh auth login`.

### 2. Startup
Start the environment:
```bash
docker-compose up -d
```

### 3. Creating and Deploying Subgraph

You can use the automated script:
```bash
./index.sh
```

Or manually:
```bash
# Create the subgraph in the node
curl -X POST http://localhost:8020/ --data '{"jsonrpc":"2.0","method":"subgraph_create","params":{"name":"custom/subgraph"},"id":1}'

# Deploy the subgraph using the IPFS hash
curl -X POST http://localhost:8020/ --data '{"jsonrpc":"2.0","method":"subgraph_deploy","params":{"name":"custom/subgraph","ipfs_hash":"QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw"},"id":1}'
```

### 4. Monitoring Logs
View logs for the graph-node service:
```bash
docker-compose logs -f graph-node
```

## Maintenance
- **Database:** Stored in `./postgres-data`
- **IPFS:** Stored in `./ipfs-data`
