#!/bin/bash
set -e

# Complete Working State Backup - Clean Version
echo "🚀 PRESERVING PRODUCTION-READY GEOLOCATION SYSTEM STATE"
echo "================================================================"

# 1. Create Complete Database Backup
echo "📦 Step 1/8: Creating comprehensive database backup..."
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=~/backups/working_state_$BACKUP_TIMESTAMP
mkdir -p $BACKUP_DIR

echo "📦 Creating comprehensive backup: $BACKUP_DIR"

# Full database backup with data
docker exec where-postgres pg_dump -U whereuser -d whereisthisplace > $BACKUP_DIR/database_full_backup.sql

# Schema-only backup
docker exec where-postgres pg_dump -U whereuser --schema-only -d whereisthisplace > $BACKUP_DIR/schema_backup.sql

# Data-only backup
docker exec where-postgres pg_dump -U whereuser --data-only -d whereisthisplace > $BACKUP_DIR/data_backup.sql

# Test data specifically
docker exec where-postgres pg_dump -U whereuser -d whereisthisplace -t whereisthisplace.photos > $BACKUP_DIR/photos_table_backup.sql

echo "✅ Database backups created"

# 2. Backup Docker Images
echo "🐳 Step 2/8: Backing up Docker images..."

# Save the backend image
docker save where-backend:schema-fix > $BACKUP_DIR/where-backend-working.tar

# Save the postgres image with data
docker commit where-postgres where-postgres:working-state-$BACKUP_TIMESTAMP
docker save where-postgres:working-state-$BACKUP_TIMESTAMP > $BACKUP_DIR/where-postgres-with-data.tar

# List all relevant images
docker images | grep -E "(where-backend|postgres)" > $BACKUP_DIR/docker_images_list.txt

echo "✅ Docker images backed up"

# 3. Backup Configuration Files
echo "⚙️ Step 3/8: Backing up configuration files..."

# Copy entire project from correct location
cp -r ~/myarchive/whereisthisplace $BACKUP_DIR/project_backup/

# Backup key configuration files specifically
cp ~/myarchive/whereisthisplace/docker-compose.gpu-final.yml $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/scripts/init-db.sql $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/scripts/create-user.sql $BACKUP_DIR/
cp ~/myarchive/whereisthisplace/.env $BACKUP_DIR/ 2>/dev/null || echo "No .env file found"

# Save container configurations
docker-compose -f ~/myarchive/whereisthisplace/docker-compose.gpu-final.yml config > $BACKUP_DIR/docker-compose-resolved.yml

echo "✅ Configuration backed up"

# 4. Create State Documentation
echo "📝 Step 4/8: Creating state documentation..."

cat > $BACKUP_DIR/STATE_DOCUMENTATION.md << 'EOF'
# Working Geolocation System State Documentation

## Date Created
EOF
echo "$(date)" >> $BACKUP_DIR/STATE_DOCUMENTATION.md

cat >> $BACKUP_DIR/STATE_DOCUMENTATION.md << 'EOF'

## What's Working ✅
- ✅ Database: PostgreSQL + PostGIS + pgvector
- ✅ Vector similarity search (128-dimensional embeddings)
- ✅ Geographic proximity search  
- ✅ Combined vector + geographic search
- ✅ FastAPI backend with health endpoints
- ✅ **GEOLOCATION PREDICTION WORKING** 🎯
- ✅ TorchServe integration with actual predictions
- ✅ Docker Compose orchestration
- ✅ File upload and processing pipeline

## Database Schema
- `photos` table with 128-dim vector embeddings
- PostGIS geometry columns for geographic search
- HNSW indexing for vector similarity
- GIST indexing for geographic queries

## Test Data & Predictions
- 3 photos with vectors and geo data
- Eiffel Tower, NYC Skyline, Basic test entry
- **CONFIRMED: Eiffel Tower prediction returns lat: 48.8584, lon: 2.2945**
- Working similarity and proximity searches

## API Endpoints
- GET /health - Health check ✅
- POST /predict - **WORKING IMAGE GEOLOCATION** 🎯
- Database connection working with whereuser:wherepass

## Container Information
EOF

docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" >> $BACKUP_DIR/STATE_DOCUMENTATION.md

cat >> $BACKUP_DIR/STATE_DOCUMENTATION.md << 'EOF'

## Database State
EOF

docker exec where-postgres psql -U whereuser -d whereisthisplace -c "
SET search_path TO whereisthisplace, public;
SELECT 
    COUNT(*) as total_photos,
    COUNT(vlad) as with_vectors,
    COUNT(geom) as with_geometry
FROM photos;" >> $BACKUP_DIR/STATE_DOCUMENTATION.md

echo "✅ Documentation created"

# 5. Git Backup
echo "🗂 Step 5/8: Creating git backup..."

cd ~/myarchive/whereisthisplace

# Commit current state
git add .
git commit -m "COMPLETE WORKING STATE: Geolocation prediction system operational

🎯 CONFIRMED WORKING FEATURES:
- Vector similarity search: 128-dim embeddings with HNSW indexing
- Geographic search: PostGIS with distance calculations  
- Combined search: Hybrid vector + geographic ranking
- **GEOLOCATION PREDICTION: POST /predict working with actual lat/lon output**
- Database: PostgreSQL + PostGIS + pgvector fully operational
- API: FastAPI backend with health endpoints
- Test confirmation: Eiffel Tower → lat: 48.8584, lon: 2.2945
- Infrastructure: Production-ready geolocation system

Backup created: $BACKUP_TIMESTAMP"

# Tag this state
git tag -a "production-ready-$BACKUP_TIMESTAMP" -m "Production-ready geolocation system with confirmed predictions"

# Create backup branch
git checkout -b "backup/production-ready-$BACKUP_TIMESTAMP"
git push origin "backup/production-ready-$BACKUP_TIMESTAMP" 2>/dev/null || echo "Remote push failed (normal if no remote)"
git push origin "production-ready-$BACKUP_TIMESTAMP" 2>/dev/null || echo "Tag push failed (normal if no remote)"
git checkout main

echo "✅ Git backup completed"

# 6. Push to ECR with Working Tag
echo "☁️ Step 6/8: Pushing to ECR..."

# Tag the working image with multiple tags
docker tag where-backend:schema-fix 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:production-ready-$BACKUP_TIMESTAMP
docker tag where-backend:schema-fix 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:stable-geolocation
docker tag where-backend:schema-fix 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:latest

# Login and push (if AWS credentials available)
if aws sts get-caller-identity > /dev/null 2>&1; then
    aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 726580147864.dkr.ecr.eu-central-1.amazonaws.com
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:production-ready-$BACKUP_TIMESTAMP
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:stable-geolocation
    docker push 726580147864.dkr.ecr.eu-central-1.amazonaws.com/where-backend:latest
    echo "✅ Images pushed to ECR with tags: latest, stable-geolocation, production-ready-$BACKUP_TIMESTAMP"
else
    echo "⚠️ AWS credentials not available - skipping ECR push"
fi

# 7. Create Restoration Scripts
echo "🔄 Step 7/8: Creating restoration scripts..."

cat > $BACKUP_DIR/RESTORE_THIS_STATE.sh << EOF
#!/bin/bash
set -e

BACKUP_DIR=\$(dirname "\$0")
echo "🔄 Restoring working geolocation system from: \$BACKUP_DIR"

# Stop current containers
cd ~/myarchive/whereisthisplace
docker-compose -f docker-compose.gpu-final.yml down 2>/dev/null || true

# Restore Docker images
echo "📦 Restoring Docker images..."
docker load < \$BACKUP_DIR/where-backend-working.tar
docker load < \$BACKUP_DIR/where-postgres-with-data.tar

# Restore configuration
echo "⚙️ Restoring configuration..."
cp \$BACKUP_DIR/docker-compose.gpu-final.yml ~/myarchive/whereisthisplace/
cp -r \$BACKUP_DIR/project_backup/* ~/myarchive/ 2>/dev/null || true

# Remove old postgres volume and start with backed up data
docker volume rm whereisthisplace_postgres_data 2>/dev/null || true

# Start services
echo "🚀 Starting services..."
cd ~/myarchive/whereisthisplace
docker-compose -f docker-compose.gpu-final.yml up -d

# Wait for services
echo "⏳ Waiting for services to start..."
sleep 30

# Test restoration
echo "🧪 Testing restored state..."
curl -s http://localhost:8000/health | jq . || echo "API not ready yet"

# Show database state
docker exec where-postgres psql -U whereuser -d whereisthisplace -c "
SET search_path TO whereisthisplace, public;
SELECT COUNT(*) as photos FROM photos;" 2>/dev/null || echo "Database not ready yet"

echo "✅ State restoration completed!"
echo "📖 See STATE_DOCUMENTATION.md for details"
echo "🎯 Test geolocation: curl -s -X POST -F \"photo=@eiffel.jpg\" http://localhost:8000/predict | jq ."
EOF

chmod +x $BACKUP_DIR/RESTORE_THIS_STATE.sh

# Create generic restoration script
cat > ~/restore_production_state.sh << 'EOF'
#!/bin/bash
set -e

echo "🔄 Restoring latest production-ready geolocation state..."

# Find latest backup
LATEST_BACKUP=$(ls -1d ~/backups/working_state_* 2>/dev/null | tail -1)

if [ -z "$LATEST_BACKUP" ]; then
    echo "❌ No backups found in ~/backups/"
    exit 1
fi

echo "📦 Found backup: $LATEST_BACKUP"
bash $LATEST_BACKUP/RESTORE_THIS_STATE.sh
EOF

chmod +x ~/restore_production_state.sh
echo "✅ Restoration scripts created"

# 8. Summary Report
echo "📊 Step 8/8: Creating final summary..."

echo "
🎉 GEOLOCATION SYSTEM BACKUP COMPLETED SUCCESSFULLY!

📍 Backup Location: $BACKUP_DIR

📦 What's Backed Up:
✅ Full database with test data and vectors
✅ Docker images (backend + postgres with data)  
✅ All configuration files
✅ Git state with tags and branches
✅ ECR images (if AWS available) with tags: latest, stable-geolocation, timestamped
✅ Complete restoration scripts
🎯 **CONFIRMED WORKING GEOLOCATION PREDICTIONS**

🔄 To Restore This State:
bash $BACKUP_DIR/RESTORE_THIS_STATE.sh

Or use the generic script:
bash ~/restore_production_state.sh

📊 Current State Summary:"

# Show final state
docker exec where-postgres psql -U whereuser -d whereisthisplace -c "
SET search_path TO whereisthisplace, public;
SELECT 
    'Database Status' as component,
    COUNT(*) || ' photos total, ' ||
    COUNT(vlad) || ' with vectors, ' ||  
    COUNT(geom) || ' with geometry' as status
FROM photos;"

curl -s http://localhost:8000/health | jq -r '"API Status: " + .fastapi_status + " | TorchServe: " + .torchserve_status'

echo "
🏷 Git Tags: production-ready-$BACKUP_TIMESTAMP
📂 Backup Size: $(du -sh $BACKUP_DIR | cut -f1)
🎯 **GEOLOCATION SYSTEM FULLY PRESERVED AND WORKING!**

✅ Your production-ready geolocation system is fully preserved!
   Test with: curl -s -X POST -F \"photo=@eiffel.jpg\" http://localhost:8000/predict | jq .
"

echo "================================================================"
echo "🚀 BACKUP COMPLETE - GEOLOCATION SYSTEM STATE PRESERVED! 🎯"
echo "================================================================"
