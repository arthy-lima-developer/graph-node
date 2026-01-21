#!/bin/bash

# Exit on error
set -e

echo "🐳 Starting Docker Installation for Ubuntu..."

# 1. Update system packages
echo "🔄 Updating system packages..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# 2. Add Docker GPG key
echo "🔑 Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# 3. Add Docker repository
echo "📂 Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# 4. Install Docker Engine and Docker Compose
echo "📦 Installing Docker Engine and Docker Compose..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Start and enable Docker service (needed in some WSL setups)
echo "🔌 Starting Docker service..."
sudo service docker start || echo "Note: Service start might vary on your WSL configuration."

# 6. Configure Docker to run without sudo
echo "👥 Adding user to docker group..."
sudo usermod -aG docker $USER

echo "✅ Installation complete!"
echo "⚠️  IMPORTANT: To apply group changes, YOU MUST RESTART your WSL terminal (or run: exec su -l $USER)"
echo "🚀 Try running: docker run hello-world"
