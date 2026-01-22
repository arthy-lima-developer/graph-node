# 🏗️ AWS Architecture Documentation

## Overview

This document describes the Graph Node infrastructure deployed on AWS using CloudFormation.

---

## Architecture Diagram

```
                                    ┌─────────────────────────────────────┐
                                    │           INTERNET                  │
                                    └─────────────────┬───────────────────┘
                                                      │
                                                      ▼
                              ┌───────────────────────────────────────────┐
                              │         AWS CloudFront CDN                │
                              │   • HTTPS termination                     │
                              │   • DDoS protection                       │
                              │   • Global edge caching                   │
                              │   URL: d3ugkaojqkfud0.cloudfront.net     │
                              └─────────────────┬─────────────────────────┘
                                                │
                                                ▼ (HTTP:8000)
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS EC2 Instance                                │
│                          (t3.medium - 2 vCPU, 4GB RAM)                      │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Docker Compose Stack                            │ │
│  │                                                                        │ │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐ │ │
│  │  │   graph-node     │  │     postgres     │  │        ipfs          │ │ │
│  │  │                  │  │                  │  │                      │ │ │
│  │  │  • Port 8000     │  │  • Port 5432     │  │  • Port 5001         │ │ │
│  │  │    (GraphQL)     │  │  • Stores all    │  │  • Stores subgraph   │ │ │
│  │  │  • Port 8020     │  │    indexed data  │  │    manifests, ABIs   │ │ │
│  │  │    (JSON-RPC)    │  │  • Subgraph      │  │  • WASM mappings     │ │ │
│  │  │  • Port 8030     │  │    schemas       │  │  • Schema files      │ │ │
│  │  │    (Status)      │  │  • Block cache   │  │                      │ │ │
│  │  │                  │  │                  │  │                      │ │ │
│  │  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘ │ │
│  │           │                     │                       │             │ │
│  │           └─────────────────────┴───────────────────────┘             │ │
│  │                    Internal Docker Network                            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                     EBS Volume (gp3 SSD)                               │ │
│  │                         100 GB                                         │ │
│  │                                                                        │ │
│  │   /home/ubuntu/graph-node/postgres-data/  ← PostgreSQL data           │ │
│  │   /home/ubuntu/graph-node/ipfs-data/      ← IPFS pinned files         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                                │
                                                ▼ (HTTPS RPC)
                              ┌───────────────────────────────────────────┐
                              │         Gnosis Chain RPC                  │
                              │   https://rpc.gnosischain.com             │
                              │   (Public endpoint)                       │
                              └───────────────────────────────────────────┘
```

---

## AWS Services Used

### 1. CloudFront (CDN)
| Property | Value |
|----------|-------|
| **Purpose** | HTTPS termination, global CDN, DDoS protection |
| **Origin** | EC2 instance port 8000 |
| **SSL** | Automatic (AWS default certificate) |
| **Caching** | Disabled for GraphQL (dynamic data) |
| **Cost** | ~$0-10/month (based on traffic) |

### 2. EC2 (Compute)
| Property | Value |
|----------|-------|
| **Instance Type** | t3.medium |
| **vCPU** | 2 |
| **RAM** | 4 GB |
| **OS** | Ubuntu 22.04 LTS |
| **Region** | us-east-1 |
| **Cost** | ~$30/month |

### 3. EBS (Storage)
| Property | Value |
|----------|-------|
| **Volume Type** | gp3 (General Purpose SSD) |
| **Size** | 100 GB |
| **IOPS** | 3000 (baseline) |
| **Throughput** | 125 MB/s |
| **Cost** | ~$8/month |

### 4. VPC & Security Group
| Property | Value |
|----------|-------|
| **VPC** | Default VPC (172.31.0.0/16) |
| **Ports Open** | 22 (SSH), 8000, 8020, 8030 |
| **Source** | 0.0.0.0/0 (anywhere) |

---

## Docker Services

### graph-node
| Property | Value |
|----------|-------|
| **Image** | graphprotocol/graph-node:latest |
| **Purpose** | Indexes blockchain data, serves GraphQL API |
| **Ports** | 8000 (GraphQL), 8020 (JSON-RPC), 8030 (Status) |
| **Memory** | ~500 MB (idle), up to 2 GB (active indexing) |

**Environment Variables:**
```yaml
postgres_host: postgres
postgres_user: graph-node
postgres_pass: let-me-in
postgres_db: graph-node
ipfs: 'ipfs:5001'
ethereum: 'gnosis:https://rpc.gnosischain.com'
GRAPH_LOG: info
GRAPH_GRAPHQL_HTTP_CORS: '*'
```

### postgres
| Property | Value |
|----------|-------|
| **Image** | postgres:12 |
| **Purpose** | Stores indexed entities, subgraph schemas, block cache |
| **Port** | 5432 (internal only) |
| **Data** | Persisted to `./postgres-data/` |

**What's stored:**
- Indexed entities (ProposalEntity, Pool, Swap, Candle, etc.)
- Subgraph deployment metadata
- Block cache for the indexed chains
- Query execution data

### ipfs
| Property | Value |
|----------|-------|
| **Image** | ipfs/kubo:latest |
| **Purpose** | Stores and retrieves subgraph files |
| **Port** | 5001 (internal only) |
| **Data** | Persisted to `./ipfs-data/` |

**What's stored:**
- Subgraph manifests (subgraph.yaml)
- ABIs (contract interfaces)
- WASM mappings (compiled AssemblyScript)
- GraphQL schemas

---

## Data Flow

### 1. Subgraph Deployment
```
User runs ./deploy.sh
       │
       ▼
┌──────────────────┐     ┌──────────────────┐
│  IPFS Gateway    │────▶│   Local IPFS     │
│  (ipfs.io)       │     │   (pinned)       │
└──────────────────┘     └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │   Graph Node     │
                         │  (JSON-RPC 8020) │
                         └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │   PostgreSQL     │
                         │  (deployment     │
                         │   registered)    │
                         └──────────────────┘
```

### 2. Indexing Process
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Gnosis RPC     │────▶│   Graph Node     │────▶│   PostgreSQL     │
│   (blocks)       │     │  (processes      │     │  (stores         │
│                  │     │   events)        │     │   entities)      │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

### 3. Query Execution
```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   CloudFront     │────▶│   Graph Node     │────▶│   PostgreSQL     │
│   (HTTPS)        │     │  (GraphQL 8000)  │     │  (query data)    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
```

---

## Deployed Subgraphs

| Name | IPFS Hash | Network | Start Block |
|------|-----------|---------|-------------|
| futarchy-complete-new-v1 | `QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw` | Gnosis | 44,225,271 |
| algebra-proposal-candles-v1 | `QmcT9gLXG2eySbqv56ef5gk6C95BVSUxQstS3FBeEFoirG` | Gnosis | 40,620,029 |

---

## Endpoints

| Purpose | URL |
|---------|-----|
| **GraphQL (CloudFront)** | `https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/<NAME>` |
| **GraphQL (Direct)** | `http://34.195.104.118:8000/subgraphs/name/<NAME>` |
| **Indexing Status** | `http://34.195.104.118:8030/graphql` |
| **JSON-RPC Deploy** | `http://34.195.104.118:8020/` |
| **SSH Access** | `ssh -i graph-node-key.pem ubuntu@34.195.104.118` |

---

## Cost Summary

| Service | Monthly Cost |
|---------|-------------|
| EC2 t3.medium | $30 |
| EBS 100GB gp3 | $8 |
| CloudFront | $0-10 |
| Data Transfer | $0-5 |
| **Total** | **~$40-55/month** |

---

## Scaling Considerations

### When to Scale Up
- More than 5-10 subgraphs
- High query volume (>1000 req/min)
- Complex subgraphs with many entities

### Upgrade Path
1. **EC2**: t3.large (2 vCPU, 8GB) → t3.xlarge (4 vCPU, 16GB)
2. **EBS**: Increase size or switch to io2 for higher IOPS
3. **RDS**: Move PostgreSQL to managed RDS for automated backups
4. **ALB**: Add Application Load Balancer for multiple EC2 instances
