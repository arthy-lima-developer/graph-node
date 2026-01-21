# Graph Node - Private Indexer

Custom Graph Node setup for indexing subgraphs on Gnosis Chain.

## 🚀 Quick Start

### 1. Prerequisites
- [Natively installed Docker](file:///home/arthur/graph-node/install-docker.sh) (Ubuntu/WSL).
- Docker and Docker Compose installed.
- Logged into GitHub via `gh auth login`.

> [!TIP]
> If you don't have Docker installed in WSL, run: `./install-docker.sh` and restart your terminal.

### 2. Startup
Start the environment:
```bash
docker-compose up -d
```

### 3. Deploying Subgraphs
You can deploy multiple subgraphs with different names and hashes.

**Default deployment:** (futarchy-complete-new)
```bash
./index.sh
```

**Custom deployment:**
```bash
./index.sh <subgraph-name> <ipfs-hash>
# Example:
./index.sh my-custom-subgraph QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw
```

---

## 📊 Querying

Once deployed, your subgraph is available at:

- **GraphQL Endpoint:** `http://localhost:8000/subgraphs/name/<subgraph-name>`
- **GraphiQL Interface:** `http://localhost:8000/subgraphs/name/<subgraph-name>/graphql`

**Example Query:**
```graphql
{
  _meta {
    block {
      number
      hash
    }
    hasIndexingErrors
  }
}
```

---

## 🧐 Monitoring & Logs

Use the `logs.sh` script to monitor indexing progress:

- **Follow all logs:** `./logs.sh`
- **Show errors only:** `./logs.sh --errors`
- **Export logs to file:** `./logs.sh --export` (saves to `indexing_logs.txt`)

---

## 🛠 Maintenance
- **Database:** Stored in `./postgres-data`
- **IPFS:** Stored in `./ipfs-data`
- **Reset everything:** `docker-compose down -v` (Warning: deletes all data)

