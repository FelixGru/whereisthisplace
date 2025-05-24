"""add photos table with gis and vector indexes

Revision ID: 202405_add_photos_table
Revises: 
Create Date: 2024-05-01 00:00:00
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '202405_add_photos_table'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.execute('CREATE EXTENSION IF NOT EXISTS postgis')
    op.execute('CREATE EXTENSION IF NOT EXISTS pgvector')

    op.execute(
        """
        CREATE TABLE photos (
            id SERIAL PRIMARY KEY,
            lat DOUBLE PRECISION NOT NULL,
            lon DOUBLE PRECISION NOT NULL,
            geom geometry(Point,4326),
            vlad vector(128)
        )
        """
    )

    op.execute(
        """
        CREATE OR REPLACE FUNCTION update_geom()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.geom = ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326);
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )

    op.execute(
        """
        CREATE TRIGGER update_photos_geom
        BEFORE INSERT OR UPDATE ON photos
        FOR EACH ROW EXECUTE FUNCTION update_geom();
        """
    )

    op.execute('CREATE INDEX photos_geom_gist ON photos USING GIST (geom)')
    op.execute('CREATE INDEX photos_vlad_hnsw ON photos USING hnsw (vlad vector_l2_ops)')

def downgrade():
    op.execute('DROP INDEX IF EXISTS photos_vlad_hnsw')
    op.execute('DROP INDEX IF EXISTS photos_geom_gist')
    op.execute('DROP TRIGGER IF EXISTS update_photos_geom ON photos')
    op.execute('DROP FUNCTION IF EXISTS update_geom')
    op.execute('DROP TABLE IF EXISTS photos')
    op.execute('DROP EXTENSION IF EXISTS pgvector')
    op.execute('DROP EXTENSION IF EXISTS postgis')

