# 🚀 AWS Deployment Guide - Graph Node

Complete step-by-step guide to deploy Graph Node on AWS with CloudFront.

**Tested and working as of January 2026.**

---

## 📋 Prerequisites

- AWS Account (free tier works)
- Linux/WSL terminal
- Your subgraph IPFS hash

---

## Step 1: Install AWS CLI

```bash
# Install dependencies
sudo apt update && sudo apt install -y unzip curl

# Download AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Install
unzip awscliv2.zip
sudo ./aws/install

# Verify (should show version 2.x)
aws --version
```

---

## Step 2: Get AWS Credentials

1. Go to **AWS Console** → https://console.aws.amazon.com
2. Click your username (top right) → **Security Credentials**
3. Scroll to **Access Keys** → **Create Access Key**
4. Choose **"Command Line Interface (CLI)"** → Check "I understand" → Create
5. **Save both keys immediately** (you won't see the secret again!)

---

## Step 3: Configure AWS CLI

```bash
aws configure
```

Enter when prompted:
```
AWS Access Key ID: AKIA................
AWS Secret Access Key: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Default region name: us-east-1
Default output format: json
```

Verify it works:
```bash
aws sts get-caller-identity
```

You should see your account ID.

---

## Step 4: Create Default VPC (Required!)

> ⚠️ **Important:** New AWS accounts often don't have a default VPC. This step is required.

```bash
aws ec2 create-default-vpc
```

If you see "already exists" error, that's fine - continue to next step.

---

## Step 5: Create SSH Key Pair

```bash
# Create key pair and save to file
aws ec2 create-key-pair \
  --key-name graph-node-key \
  --query 'KeyMaterial' \
  --output text > graph-node-key.pem

# Set secure permissions
chmod 400 graph-node-key.pem

# Verify file exists
ls -la graph-node-key.pem
```

**Keep this file safe! You need it to SSH into your server.**

---

## Step 6: Clone This Repository

```bash
git clone https://github.com/arthy-lima-developer/graph-node.git
cd graph-node
```

---

## Step 7: Deploy the Stack

```bash
aws cloudformation create-stack \
  --stack-name graph-node \
  --template-body file://aws/cloudformation.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=graph-node-key \
  --region us-east-1
```

---

## Step 8: Wait for Deployment (~5-10 minutes)

Check status every 30 seconds:
```bash
aws cloudformation describe-stacks \
  --stack-name graph-node \
  --query 'Stacks[0].StackStatus' \
  --output text
```

Wait until it says: **`CREATE_COMPLETE`**

If it says `ROLLBACK_IN_PROGRESS`, check errors:
```bash
aws cloudformation describe-stack-events \
  --stack-name graph-node \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
  --output table
```

---

## Step 9: Get Your Endpoints

```bash
aws cloudformation describe-stacks \
  --stack-name graph-node \
  --query 'Stacks[0].Outputs' \
  --output table
```

You'll see:
- **EC2PublicIP** - Your server IP (e.g., `34.195.104.118`)
- **CloudFrontURL** - Your HTTPS endpoint (e.g., `https://abc123.cloudfront.net`)
- **SSHCommand** - Copy this to SSH in

---

## Step 10: Wait for EC2 to Initialize (~3-5 minutes)

The EC2 is installing Docker and cloning the repo. Wait 3-5 minutes, then SSH in:

```bash
ssh -i graph-node-key.pem ubuntu@<EC2-PUBLIC-IP>
```

Example:
```bash
ssh -i graph-node-key.pem ubuntu@34.195.104.118
```

---

## Step 11: Verify Setup (Inside EC2)

```bash
cd ~/graph-node

# Check Docker is running
docker compose ps
```

You should see `graph-node`, `postgres`, and `ipfs` containers running.

If not, wait a minute and try:
```bash
docker compose up -d
```

---

## Step 12: Deploy Your Subgraph

```bash
cd ~/graph-node

# Deploy futarchy-complete-new-v1
./deploy.sh futarchy-complete-new-v1 QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw

# Deploy algebra-proposal-candles-v1
./deploy.sh algebra-proposal-candles-v1 QmcT9gLXG2eySbqv56ef5gk6C95BVSUxQstS3FBeEFoirG
```

**Available Subgraphs:**

| Name | IPFS Hash |
|------|-----------|
| futarchy-complete-new-v1 | `QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw` |
| algebra-proposal-candles-v1 | `QmcT9gLXG2eySbqv56ef5gk6C95BVSUxQstS3FBeEFoirG` |

---

## Step 13: Access Your Subgraph

Your GraphQL endpoint (via CloudFront with HTTPS):
```
https://<CLOUDFRONT-URL>/subgraphs/name/<SUBGRAPH-NAME>
```

Example:
```
https://d3ugkaojqkfud0.cloudfront.net/subgraphs/name/algebra-proposal-candles
```

Test it:
```bash
curl https://<CLOUDFRONT-URL>/subgraphs/name/algebra-proposal-candles \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ _meta { block { number } } }"}'
```

---

## 📊 Monitor & Logs

SSH into EC2, then:
```bash
cd ~/graph-node

# View logs
./logs.sh

# Check container status
docker stats

# Check indexing status
curl -s http://localhost:8030/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ indexingStatuses { subgraph synced health } }"}' | jq
```

---

## 💰 Cost Breakdown

| Resource | Monthly Cost |
|----------|-------------|
| EC2 t3.medium | ~$30 |
| EBS 100GB gp3 | ~$8 |
| CloudFront | ~$0-10 |
| Data Transfer | ~$0-5 |
| **Total** | **~$40-55/month** |

---

## 🗑️ Delete Everything

To completely remove all AWS resources:
```bash
aws cloudformation delete-stack --stack-name graph-node --region us-east-1
```

---

## 🔧 Troubleshooting

### Stack creation failed with "No default VPC"
```bash
aws ec2 create-default-vpc
# Then delete failed stack and retry
aws cloudformation delete-stack --stack-name graph-node
# Wait 1 minute, then run create-stack again
```

### Can't SSH - "Permission denied"
```bash
chmod 400 graph-node-key.pem
```

### Can't SSH - "Connection refused"
Wait 3-5 minutes for EC2 to fully boot.

### Docker not running
```bash
sudo systemctl start docker
cd ~/graph-node && docker compose up -d
```

### Subgraph not syncing
```bash
cd ~/graph-node
./logs.sh --errors
```

### CloudFront returns 502 Bad Gateway
- Wait 15-20 minutes for CloudFront distribution to fully deploy
- Verify EC2 is running and graph-node container is up

---

## 📞 Quick Reference

| Action | Command |
|--------|---------|
| SSH into EC2 | `ssh -i graph-node-key.pem ubuntu@<IP>` |
| View logs | `./logs.sh` |
| Deploy subgraph | `./deploy.sh <name> <hash>` |
| Check containers | `docker compose ps` |
| Restart services | `docker compose restart` |
| Stop services | `docker compose down` |
| Start services | `docker compose up -d` |
| Check stack status | `aws cloudformation describe-stacks --stack-name graph-node` |
| Delete everything | `aws cloudformation delete-stack --stack-name graph-node` |
