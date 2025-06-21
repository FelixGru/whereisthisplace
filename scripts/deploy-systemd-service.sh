#!/bin/bash

# Deploy systemd service setup to remote EC2 instance
# Usage: ./scripts/deploy-systemd-service.sh

set -e

# Configuration (same as deploy-env.sh)
EC2_USER="ubuntu"
EC2_HOST="52.28.72.57"
SSH_KEY="./../../Downloads/where-key.pem"
REMOTE_PATH="/home/ubuntu/myarchive/whereisthisplace"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Deploying systemd service to EC2 instance...${NC}"

# Check if setup script exists locally
if [ ! -f "scripts/setup-systemd-service.sh" ]; then
    echo -e "${RED}❌ Error: scripts/setup-systemd-service.sh not found${NC}"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Error: SSH key not found at $SSH_KEY${NC}"
    exit 1
fi

# Test SSH connection
echo -e "${YELLOW}🔍 Testing SSH connection...${NC}"
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$EC2_USER@$EC2_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${RED}❌ Error: Cannot connect to EC2 instance${NC}"
    exit 1
fi

# Copy the setup script to remote
echo -e "${YELLOW}📁 Copying systemd setup script...${NC}"
scp -i "$SSH_KEY" scripts/setup-systemd-service.sh "$EC2_USER@$EC2_HOST:$REMOTE_PATH/scripts/"

# Make the script executable on remote
echo -e "${YELLOW}🔧 Making script executable on remote...${NC}"
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_HOST" "chmod +x $REMOTE_PATH/scripts/setup-systemd-service.sh"

# Run the setup script on remote
echo -e "${YELLOW}⚙️  Running systemd service setup on EC2...${NC}"
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_HOST" "cd $REMOTE_PATH && ./scripts/setup-systemd-service.sh"

echo -e "${GREEN}🎉 Systemd service deployed and configured successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Next steps on EC2:${NC}"
echo -e "${YELLOW}  1. Start service: sudo systemctl start whereisthisplace-backend${NC}"
echo -e "${YELLOW}  2. Check status: sudo systemctl status whereisthisplace-backend${NC}"
echo -e "${YELLOW}  3. View logs:   sudo journalctl -u whereisthisplace-backend -f${NC}"
echo ""
echo -e "${YELLOW}💡 The service is configured to start automatically on boot!${NC}"
echo -e "${YELLOW}   Your backend will now survive EC2 reboots and container crashes.${NC}" 