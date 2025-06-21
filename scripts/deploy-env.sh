#!/bin/bash

# Deploy .env file to remote EC2 instance
# Usage: ./scripts/deploy-env.sh

set -e

# Configuration
EC2_USER="ubuntu"  # Change if you use different user (e.g., ec2-user)
EC2_HOST="52.28.72.57"  # Update with your EC2 IP
SSH_KEY="./../../Downloads/where-key.pem"  # Update with your SSH key path
REMOTE_PATH="/home/ubuntu/myarchive/whereisthisplace"  # Update with your remote path

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Deploying .env file to EC2 instance...${NC}"

# Check if .env file exists locally
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Error: .env file not found in current directory${NC}"
    echo "Create a .env file with your environment variables first."
    exit 1
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}❌ Error: SSH key not found at $SSH_KEY${NC}"
    echo "Update the SSH_KEY variable in this script."
    exit 1
fi

# Test SSH connection
echo -e "${YELLOW}🔍 Testing SSH connection...${NC}"
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 "$EC2_USER@$EC2_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${RED}❌ Error: Cannot connect to EC2 instance${NC}"
    echo "Check your EC2_HOST, EC2_USER, and SSH_KEY settings."
    exit 1
fi

# Copy .env file
echo -e "${YELLOW}📁 Copying .env file...${NC}"
scp -i "$SSH_KEY" .env "$EC2_USER@$EC2_HOST:$REMOTE_PATH/.env"

# Verify the file was copied
echo -e "${YELLOW}✅ Verifying deployment...${NC}"
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_HOST" "cd $REMOTE_PATH && ls -la .env"

echo -e "${GREEN}🎉 .env file successfully deployed to EC2!${NC}"
echo -e "${YELLOW}💡 Remember to restart your Docker containers to pick up the new environment variables${NC}"
echo -e "${YELLOW}   SSH command: ssh -i $SSH_KEY $EC2_USER@$EC2_HOST${NC}"
echo -e "${YELLOW}   Restart command: cd $REMOTE_PATH && docker-compose -f docker-compose.gpu-final.yml up -d${NC}" 