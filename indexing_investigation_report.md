# 📊 Graph Node Indexing Investigation Report

## 🎯 Goal
Successfully deploy and index the subgraph **`futarchy-complete-new`** on **Gnosis Chain** using a local Graph Node environment in WSL.

## ✅ RESOLVED

### Root Causes Found
1. **Missing `Content-Type: application/json` header** in `index.sh` curl commands - Graph Node silently rejected all deployments
2. **IPFS files not properly pinned** - Files were added with wrong CID versions, making them inaccessible by their original Qm hashes

### Fixes Applied
1. **Fixed `index.sh`**: Added `-H 'Content-Type: application/json'` to both create and deploy curl commands
2. **Rewrote `inject-ipfs.sh`**: Now uses volume-mounted staging directory (`./ipfs-data/staging/`) to properly transfer files to the IPFS container with correct CID format

## 📈 Current Status
- **Subgraph**: `QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw`
- **Health**: healthy
- **Synced**: true
- **Network**: Gnosis Chain
- **Block**: Synced to chain head (~44274276)

## 🔧 Fixed Files
- `index.sh` - Content-Type header added
- `inject-ipfs.sh` - Volume-mount approach for correct CID handling
