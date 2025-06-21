# Systemd Service for WhereIsThisPlace Backend

This document explains how to set up a systemd service to manage your Docker Compose backend on EC2.

## 🔧 Corrected Systemd Service Configuration

Here's your original configuration with corrections applied:

### ❌ Original Issues:
- Wrong user: `ec2-user` → should be `ubuntu`
- Wrong path: `/home/ec2-user/app` → should be `/home/ubuntu/myarchive/whereisthisplace`
- Missing compose file specification
- No timeout configurations
- Missing user/group settings

### ✅ Corrected Service File:

```ini
[Unit]
Description=WhereIsThisPlace GPU Backend
Documentation=https://github.com/FelixGru/whereisthisplace
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/myarchive/whereisthisplace
ExecStart=docker-compose -f docker-compose.gpu-final.yml up -d
ExecStop=docker-compose -f docker-compose.gpu-final.yml down
ExecReload=docker-compose -f docker-compose.gpu-final.yml up -d
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
SyslogIdentifier=whereisthisplace-backend

[Install]
WantedBy=multi-user.target
```

## 🚀 Deployment Options

### Option 1: Automated Deployment (Recommended)
```bash
# Deploy from your local machine
./scripts/deploy-systemd-service.sh
```

### Option 2: Manual Setup on EC2
```bash
# SSH to your EC2 instance
ssh -i ./../../Downloads/where-key.pem ubuntu@52.28.72.57

# Run the setup script
cd /home/ubuntu/myarchive/whereisthisplace
./scripts/setup-systemd-service.sh
```

## 📋 Key Improvements Made

### 1. **Correct Paths & User**
- ✅ Working directory: `/home/ubuntu/myarchive/whereisthisplace`
- ✅ User/Group: `ubuntu`
- ✅ Compose file: `docker-compose.gpu-final.yml`

### 2. **Better Service Configuration**
- ✅ `Type=forking` + `RemainAfterExit=yes` for Docker Compose
- ✅ Proper timeouts (5min start, 2min stop)
- ✅ `RestartSec=30` (wait 30s before restart attempts)

### 3. **Docker Compose Detection**
- ✅ Auto-detects v1 (`docker-compose`) vs v2 (`docker compose`)
- ✅ Explicit compose file specification

### 4. **Enhanced Reliability**
- ✅ `Wants=network-online.target` (wait for network)
- ✅ Proper logging to journald
- ✅ Security hardening

### 5. **Environment Variables**
- ✅ Docker timeout settings
- ✅ Project name configuration

## 🎯 Service Management Commands

```bash
# Start the service
sudo systemctl start whereisthisplace-backend

# Stop the service
sudo systemctl stop whereisthisplace-backend

# Check status
sudo systemctl status whereisthisplace-backend

# View logs (follow)
sudo journalctl -u whereisthisplace-backend -f

# View logs (last 100 lines)
sudo journalctl -u whereisthisplace-backend -n 100

# Restart service
sudo systemctl restart whereisthisplace-backend

# Disable auto-start
sudo systemctl disable whereisthisplace-backend

# Enable auto-start
sudo systemctl enable whereisthisplace-backend
```

## 🛡️ Multi-Layer Resilience

With this setup, your backend has **triple redundancy**:

1. **Container Level**: `restart: unless-stopped` in docker-compose
2. **Service Level**: `Restart=always` in systemd
3. **System Level**: Service starts automatically on boot

Your backend will survive:
- ✅ Container crashes
- ✅ Docker daemon restarts  
- ✅ EC2 instance reboots
- ✅ System updates requiring reboot

## 🔍 Troubleshooting

### Service Won't Start
```bash
# Check service status
sudo systemctl status whereisthisplace-backend

# Check detailed logs
sudo journalctl -u whereisthisplace-backend --no-pager

# Check Docker Compose manually
cd /home/ubuntu/myarchive/whereisthisplace
docker-compose -f docker-compose.gpu-final.yml up -d
```

### Service Starts But Containers Don't
```bash
# Check if .env file exists
ls -la /home/ubuntu/myarchive/whereisthisplace/.env

# Check Docker daemon
sudo systemctl status docker

# Check compose file syntax
docker-compose -f docker-compose.gpu-final.yml config
```

This systemd service ensures your WhereIsThisPlace backend runs reliably 24/7 on your EC2 GPU instance! 🚀 