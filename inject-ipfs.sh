#!/bin/bash

# All required IPFS hashes from the subgraph manifest
HASHES=(
  "QmWi2sSCu1k4GkteaZKiyGkGEUJk5oo84DFF4UoHC14mPw"  # Manifest
  "QmV86EVeviNNiGTKaPnsTSGfqrrMfkonTNbVPfpGunS4MZ"  # Creator ABI
  "QmWGq5ERT8HA9PX8E7dxZMQBmPgAFFTHAJmYQtdngGsJrS"  # Aggregator ABI
  "QmZeLTo7dzSZo6MDjn2JnS55rBoaSYK4ZS8KpdDHB9pfMS"  # Mapping WASM
  "Qmev6Am6auQSauTzXSmxDTN5GiLH7z1C8hkVmsdNEGHore"  # OrganizationFactory ABI
  "QmUv8bB8WVSqLk1vuDyPMFos5dWURdWR8EN1YRup8xxH7r"  # Organization ABI
  "QmPKwJtcWqvcxJn7k56mY6nuqB69fJeVGFGcseeBqdDhf8"  # Schema
  "QmPDDceiehfZSKBhVRJQ12Jh9zvcoTsgP8gPgHsUWrUJy9"  # Additional ABI
  "QmeJCNtDtLAhMwYC3cKs8fTcH2dX7M1vNQMLKEeTuYhTks"  # Additional mapping
)

GATEWAY="https://ipfs.io/ipfs"
IPFS_DATA_DIR="./ipfs-data/staging"

echo "🕵️ Starting IPFS dependency injection..."

# Create staging directory in IPFS volume
mkdir -p "$IPFS_DATA_DIR"

for hash in "${HASHES[@]}"; do
  FILE="$IPFS_DATA_DIR/$hash"
  echo -n "📡 Fetching $hash... "
  
  # Download file to the IPFS data volume
  if curl -sL --max-time 60 -o "$FILE" "$GATEWAY/$hash" 2>/dev/null; then
    if [ -s "$FILE" ]; then
      # Add to IPFS from inside the container using staged file
      ADDED=$(docker compose exec -T ipfs ipfs add -q --pin=true "/data/ipfs/staging/$hash" 2>/dev/null)
      
      if [ "$ADDED" = "$hash" ]; then
        echo "✅ Success"
      else
        echo "⚠️ Got $ADDED (trying alternative method)"
        # Try adding via cat and pipe
        ADDED2=$(cat "$FILE" | docker compose exec -T ipfs ipfs add -q --pin=true 2>/dev/null)
        if [ "$ADDED2" = "$hash" ]; then
          echo "   ✅ Fixed via pipe"
        else
          echo "   ⚠️ CID mismatch: $ADDED2"
        fi
      fi
    else
      echo "❌ Empty file"
    fi
  else
    echo "❌ Download failed"
  fi
done

echo ""
echo "🔍 Verifying all required hashes are pinned..."
for hash in "${HASHES[@]}"; do
  if docker compose exec -T ipfs ipfs pin ls "$hash" &>/dev/null; then
    echo "  ✅ $hash"
  else
    echo "  ❌ $hash (MISSING!)"
  fi
done

echo ""
echo "🚀 Running deployment..."
./index.sh
