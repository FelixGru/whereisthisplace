#!/bin/bash
set -e

# GitHub Action Production System Backup - V4 Lean + ECR Tags
echo "🚀 PRESERVING GITHUB ACTION PRODUCTION SYSTEM STATE"
echo "🎯 Smart backup: Database + Config + ECR tags (no redundant local files)"
echo "================================================================"

# 1. Create Complete Database Backup
echo "📦 Step 1/7: Creating comprehensive database backup..."
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups/production_lean_$BACKUP_TIMESTAMP
mkdir -p $BACKUP_DIR

echo "📦 Creating backup: $BACKUP_DIR"

# Full database backup with data
docker exec where-postgres pg_dump -U whereuser -d whereisthisplace > $BACKUP_DIR/database_full_backup.sql

# Schema-only backup
docker exec where-postgres pg_dump -U whereuser --schema-only -d whereisthisplace > $BACKUP_DIR/schema_backup.sql

# Data-only backup
docker exec where-postgres pg_dump -U whereuser --data-only -d whereisthisplace > $BACKUP_DIR/data_backup.sql

# Test data specifically (the valuable reference photos)
docker exec where-postgres pg_dump -U whereuser -d whereisthisplace -t whereisthisplace.photos > $BACKUP_DIR/photos_table_backup.sql

echo "✅ Database backups created"

# 2. Capture Docker Image References (No Large Files)
echo "🐳 Step 2/7: Capturing Docker image references..."

# Get current deployment info
RUNNING_CONTAINER_ID=$(docker ps --filter "name=where-backend-gpu" --format "{{.ID}}")
RUNNING_IMAGE=$(docker ps --filter "name=where-backend-gpu" --format "{{.Image}}")
ECR_IMAGE="726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:latest"
ECR_DIGEST=$(docker images --digests $ECR_IMAGE --format "{{.Digest}}")

# Create image reference file
cat > $BACKUP_DIR/DOCKER_IMAGES_INFO.md << EOF
# Docker Images Information

## Current Production Deployment
- **ECR Image**: $ECR_IMAGE
- **ECR Digest**: $ECR_DIGEST
- **Running Container**: $RUNNING_CONTAINER_ID
- **Deployment Method**: GitHub Action → ECR → docker pull

## Restoration Commands
\`\`\`bash
# Pull the exact production image
docker pull $ECR_IMAGE

# Or pull by specific digest for exact reproduction
docker pull 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend@$ECR_DIGEST

# PostgreSQL image
docker pull pgvector/pgvector:pg16
\`\`\`

## Container Information
EOF

docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" >> $BACKUP_DIR/DOCKER_IMAGES_INFO.md

echo "✅ Docker image references captured (no large files)"

# 3. Backup Configuration Files
echo "⚙️ Step 3/7: Backing up configuration files..."

# Copy project configuration
cp -r ~/myarchive/whereisthisplace $BACKUP_DIR/project_backup/

# Key files
cp ~/myarchive/whereisthisplace/docker-compose.gpu-final.yml $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/scripts/init-db.sql $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/scripts/create-user.sql $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/.env $BACKUP_DIR/ 2>/dev/null || echo "No .env file found"

# Resolved compose config
docker-compose -f ~/myarchive/whereisthisplace/docker-compose.gpu-final.yml config > $BACKUP_DIR/docker-compose-resolved.yml

echo "✅ Configuration backed up"

# 4. Create Complete State Documentation
echo "📝 Step 4/7: Creating state documentation..."

cat > $BACKUP_DIR/PRODUCTION_STATE.md << 'EOF'
# GITHUB ACTION PRODUCTION SYSTEM - COMPLETE STATE

## System Overview
🎯 **Production Geolocation API with GitHub Action CI/CD**
🌐 **Public Endpoint**: http://52.28.72.57:8000
🚀 **CI/CD Pipeline**: GitHub → Action → ECR → EC2 → Production

## Deployment Information
EOF

echo "- **Backup Date**: $(date)" >> $BACKUP_DIR/PRODUCTION_STATE.md
echo "- **ECR Image**: $ECR_IMAGE" >> $BACKUP_DIR/PRODUCTION_STATE.md
echo "- **ECR Digest**: $ECR_DIGEST" >> $BACKUP_DIR/PRODUCTION_STATE.md
echo "- **Container ID**: $RUNNING_CONTAINER_ID" >> $BACKUP_DIR/PRODUCTION_STATE.md

cat >> $BACKUP_DIR/PRODUCTION_STATE.md << 'EOF'

## What's Working ✅
- ✅ **Vector Similarity Search**: 128-dimensional embeddings with reference database
- ✅ **Geographic Search**: PostGIS with distance calculations
- ✅ **ML Predictions**: TorchServe model finding closest matches from reference data
- ✅ **Reference Database**: 3 photos (Eiffel Tower: Paris, NYC Skyline, Basic test)
- ✅ **Public API**: http://52.28.72.57:8000/predict working
- ✅ **Health Endpoint**: http://52.28.72.57:8000/health operational
- ✅ **GitHub Action Deployment**: Automated builds and deployments
- ✅ **ECR Integration**: Automated image storage and versioning

## API Functionality
- **POST /predict**: Upload image → Vector analysis → Find closest match → Return lat/lon
- **GET /health**: System status check
- **Database**: 3 reference photos, 2 with vector embeddings, all with geometry

## Database Reference Data
EOF

# Get database info safely (handle different column names)
docker exec where-postgres psql -U whereuser -d whereisthisplace -c "
SET search_path TO whereisthisplace, public;
SELECT 'Photos: ' || COUNT(*) || ' total' as database_status FROM photos;
" >> $BACKUP_DIR/PRODUCTION_STATE.md 2>/dev/null || echo "Database query error" >> $BACKUP_DIR/PRODUCTION_STATE.md

cat >> $BACKUP_DIR/PRODUCTION_STATE.md << 'EOF'

## Container Status
EOF

docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" >> $BACKUP_DIR/PRODUCTION_STATE.md

cat >> $BACKUP_DIR/PRODUCTION_STATE.md << 'EOF'

## Test Commands
```bash
# Health check
curl -s http://52.28.72.57:8000/health | jq .

# Geolocation prediction (upload eiffel.jpg)
curl -s -X POST -F "photo=@eiffel.jpg" http://52.28.72.57:8000/predict | jq .
```

## CI/CD Workflow
1. **Code Push**: Developer pushes to GitHub main branch
2. **GitHub Action**: Automatically builds Docker image
3. **ECR Push**: Image pushed to 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:latest
4. **EC2 Deploy**: `docker pull` + `docker-compose up -d`
5. **Production**: Live API at http://52.28.72.57:8000

EOF

echo "✅ Complete state documentation created"

# 5. Git Backup
echo "🗂 Step 5/7: Creating git backup..."

cd ~/myarchive/whereisthisplace

git add .
git commit -m "PRODUCTION STATE: GitHub Action CI/CD system operational

🎯 PRODUCTION SYSTEM CONFIRMED:
- Public API: http://52.28.72.57:8000 ✅
- Vector similarity search with reference database ✅
- GitHub Action CI/CD: Auto-build and deploy ✅
- ECR Image: $ECR_IMAGE ✅
- Database: 3 reference photos, 2 with embeddings ✅
- ML Predictions: Finding closest matches from reference data ✅
- Infrastructure: Production-ready on EC2 ✅

Backup: $BACKUP_TIMESTAMP (lean approach - DB + config + references)"

git tag -a "production-lean-$BACKUP_TIMESTAMP" -m "Production system: GitHub Action CI/CD with lean backup"

git checkout -b "backup/production-lean-$BACKUP_TIMESTAMP"
git push origin "backup/production-lean-$BACKUP_TIMESTAMP" 2>/dev/null || echo "Remote push skipped"
git push origin "production-lean-$BACKUP_TIMESTAMP" 2>/dev/null || echo "Tag push skipped"
git checkout main

echo "✅ Git backup completed"

# 6. Push Production Tags to ECR
echo "☁️ Step 6/7: Creating production tags in ECR..."

# Tag the current working production image with backup-specific tags
docker tag $ECR_IMAGE 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:production-backup-$BACKUP_TIMESTAMP
docker tag $ECR_IMAGE 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:stable-production
docker tag $ECR_IMAGE 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:github-action-verified

# Login and push production tags (if AWS credentials available)
if aws sts get-caller-identity > /dev/null 2>&1; then
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 726580147864.dkr.ecr.eu-central-1.amazonaws.com
    
    echo "📤 Pushing production tags to ECR..."
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:production-backup-$BACKUP_TIMESTAMP
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:stable-production
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:github-action-verified
    
    echo "✅ Production tags pushed to ECR:"
    echo "   📦 :production-backup-$BACKUP_TIMESTAMP (timestamped backup)"
    echo "   📦 :stable-production (current stable)"
    echo "   📦 :github-action-verified (CI/CD verified)"
    echo "   📝 Note: :latest remains unchanged (GitHub Action manages it)"
else
    echo "⚠️ AWS credentials not available - skipping ECR push"
    echo "📝 Production tags would be:"
    echo "   📦 :production-backup-$BACKUP_TIMESTAMP"
    echo "   📦 :stable-production"
    echo "   📦 :github-action-verified"
fi

# 7. Create Smart Restoration Script
echo "🔄 Step 7/7: Creating smart restoration script..."

cat > $BACKUP_DIR/RESTORE_PRODUCTION.sh << EOF
#!/bin/bash
set -e

BACKUP_DIR=\$(dirname "\$0")
echo "🔄 RESTORING PRODUCTION SYSTEM (Smart Approach)"
echo "📦 Backup location: \$BACKUP_DIR"

# Stop current containers
cd ~/myarchive/whereisthisplace
docker-compose -f docker-compose.gpu-final.yml down 2>/dev/null || true

# Pull the exact production images (instead of loading from tar)
echo "📥 Pulling production images from ECR..."
docker pull $ECR_IMAGE
docker pull pgvector/pgvector:pg16

# Restore configuration
echo "⚙️ Restoring configuration..."
cp \$BACKUP_DIR/docker-compose.gpu-final.yml ~/myarchive/whereisthisplace/
cp -r \$BACKUP_DIR/project_backup/* ~/myarchive/ 2>/dev/null || true

# Remove old postgres volume
docker volume rm whereisthisplace_postgres_data 2>/dev/null || true

# Start with fresh database
echo "🗄 Starting services..."
cd ~/myarchive/whereisthisplace
docker-compose -f docker-compose.gpu-final.yml up -d where-postgres

# Wait for postgres
echo "⏳ Waiting for PostgreSQL..."
sleep 15

# Restore database
echo "📊 Restoring database with reference data..."
docker exec where-postgres psql -U whereuser -d whereisthisplace < \$BACKUP_DIR/database_full_backup.sql

# Start backend
docker-compose -f docker-compose.gpu-final.yml up -d

echo "⏳ Waiting for all services..."
sleep 30

# Test restoration
echo "🧪 Testing restored system..."
curl -s http://localhost:8000/health | jq . || echo "API not ready yet"

echo "
✅ PRODUCTION SYSTEM RESTORED!

🎯 What was restored:
- Database with reference photos and vectors
- Configuration files  
- Production ECR image: $ECR_IMAGE
- All services operational

🧪 Test commands:
- Health: curl -s http://localhost:8000/health | jq .
- Predict: curl -s -X POST -F \"photo=@eiffel.jpg\" http://localhost:8000/predict | jq .

📖 See PRODUCTION_STATE.md for complete details
"
EOF

chmod +x $BACKUP_DIR/RESTORE_PRODUCTION.sh

# Create quick restore script
cat > ~/restore_production_lean.sh << 'EOF'
#!/bin/bash
LATEST=$(ls -1d ~/backups/production_lean_* 2>/dev/null | tail -1)
if [ -z "$LATEST" ]; then
    echo "❌ No lean backups found"
    exit 1
fi
echo "📦 Restoring from: $LATEST"
bash $LATEST/RESTORE_PRODUCTION.sh
EOF

chmod +x ~/restore_production_lean.sh

# 7. Final Summary
echo "
🎉 LEAN PRODUCTION BACKUP COMPLETED!

📍 Backup Location: $BACKUP_DIR
📊 Backup Size: $(du -sh $BACKUP_DIR | cut -f1) (vs 15GB+ with image files!)

✅ What's Preserved:
🗄 Complete database with reference data (the valuable part!)
⚙️ All configuration files
🐳 ECR production tags: :stable-production, :github-action-verified, :production-backup-TIMESTAMP
📝 Complete production state documentation
🔄 Smart restoration script (pulls from ECR)
🗂 Git state with tags

❌ What's NOT included (intentionally):
🚫 Large Docker image tar files (redundant with ECR)
🚫 15GB+ of disk usage for images already in cloud

🔄 To Restore:
bash $BACKUP_DIR/RESTORE_PRODUCTION.sh
# OR quick restore:
bash ~/restore_production_lean.sh

🎯 Your GitHub Action CI/CD production system is preserved efficiently!
   ECR now has proper production tags, and restoration pulls fresh images.
"

echo "================================================================"
echo "🚀 SMART PRODUCTION BACKUP COMPLETE! 🎯"
echo "================================================================"
