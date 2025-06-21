#!/bin/bash

# Setup systemd service for WhereIsThisPlace backend
# Usage: ./scripts/setup-systemd-service.sh

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔧 Setting up systemd service for WhereIsThisPlace backend...${NC}"

# Configuration based on your setup
WORKING_DIR="/home/ubuntu/myarchive/whereisthisplace"
COMPOSE_FILE="docker-compose.gpu-final.yml"
SERVICE_NAME="whereisthisplace-backend"

# Check if we're on the EC2 instance
if [ ! -d "$WORKING_DIR" ]; then
    echo -e "${RED}❌ Error: Working directory $WORKING_DIR not found${NC}"
    echo "This script should be run on the EC2 instance where the project is deployed."
    exit 1
fi

# Check if docker-compose file exists
if [ ! -f "$WORKING_DIR/$COMPOSE_FILE" ]; then
    echo -e "${RED}❌ Error: $COMPOSE_FILE not found in $WORKING_DIR${NC}"
    exit 1
fi

# Detect Docker Compose command (v1 vs v2)
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo -e "${YELLOW}📦 Using Docker Compose v1${NC}"
elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    echo -e "${YELLOW}📦 Using Docker Compose v2${NC}"
else
    echo -e "${RED}❌ Error: Docker Compose not found${NC}"
    exit 1
fi

# Create the systemd service file
echo -e "${YELLOW}📝 Creating systemd service file...${NC}"

sudo tee /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=WhereIsThisPlace GPU Backend
Documentation=https://github.com/FelixGru/whereisthisplace
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=${WORKING_DIR}
ExecStart=${COMPOSE_CMD} -f ${COMPOSE_FILE} up -d
ExecStop=${COMPOSE_CMD} -f ${COMPOSE_FILE} down
ExecReload=${COMPOSE_CMD} -f ${COMPOSE_FILE} up -d
Restart=always
RestartSec=30
TimeoutStartSec=300
TimeoutStopSec=120

# Run as ubuntu user with proper group
User=ubuntu
Group=ubuntu

# Environment
Environment=COMPOSE_PROJECT_NAME=whereisthisplace
Environment=DOCKER_CLIENT_TIMEOUT=120
Environment=COMPOSE_HTTP_TIMEOUT=120

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

# Set proper permissions
sudo chmod 644 /etc/systemd/system/${SERVICE_NAME}.service

# Reload systemd and enable the service
echo -e "${YELLOW}🔄 Reloading systemd daemon...${NC}"
sudo systemctl daemon-reload

echo -e "${YELLOW}✅ Enabling service to start on boot...${NC}"
sudo systemctl enable ${SERVICE_NAME}

echo -e "${GREEN}🎉 Systemd service '${SERVICE_NAME}' created successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Useful commands:${NC}"
echo -e "${YELLOW}  Start:   sudo systemctl start ${SERVICE_NAME}${NC}"
echo -e "${YELLOW}  Stop:    sudo systemctl stop ${SERVICE_NAME}${NC}"
echo -e "${YELLOW}  Status:  sudo systemctl status ${SERVICE_NAME}${NC}"
echo -e "${YELLOW}  Logs:    sudo journalctl -u ${SERVICE_NAME} -f${NC}"
echo -e "${YELLOW}  Restart: sudo systemctl restart ${SERVICE_NAME}${NC}"
echo ""
echo -e "${YELLOW}💡 The service is now enabled and will start automatically on boot!${NC}"
echo -e "${YELLOW}   To start it now, run: sudo systemctl start ${SERVICE_NAME}${NC}" 