"""enable PostGIS & pgvector, create photos table"""

from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry
from pgvector.sqlalchemy import Vector

# revision identifiers, used by Alembic.
revision = '202405_add_photos_table'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Enable required extensions
    op.execute('CREATE EXTENSION IF NOT EXISTS postgis')
    op.execute('CREATE EXTENSION IF NOT EXISTS vector')

    # Create photos table
    op.create_table(
        'photos',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('lat', sa.Float(), nullable=False),
        sa.Column('lon', sa.Float(), nullable=False),
        sa.Column('geom', Geometry(geometry_type='POINT', srid=4326)),
        sa.Column('vlad', Vector(128)),
    )

    # Add indexes
    op.create_index('ix_photos_geom', 'photos', ['geom'], postgresql_using='gist')
    op.create_index(
        'ix_photos_vlad',
        'photos',
        ['vlad'],
        postgresql_using='hnsw',
        postgresql_ops={'vlad': 'vector_l2_ops'},
    )


def downgrade():
    op.drop_index('ix_photos_vlad', table_name='photos')
    op.drop_index('ix_photos_geom', table_name='photos')
    op.drop_table('photos')

    op.execute('DROP EXTENSION IF EXISTS vector')
    op.execute('DROP EXTENSION IF EXISTS postgis')
