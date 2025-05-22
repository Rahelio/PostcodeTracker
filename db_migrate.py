import os
import sys
from sqlalchemy import text
from app import app, db
from models import Journey, SavedLocation, User
import logging

"""
Simple database migration script to handle the addition of new columns to the Journey table
and create the SavedLocation table.
"""

logger = logging.getLogger(__name__)

def run_migration():
    """Run database migrations for PostgreSQL."""
    try:
        # First, check if the user table exists
        result = db.session.execute(text("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'user')"))
        table_exists = result.scalar()
        
        if table_exists:
            # If table exists, drop it and recreate
            logger.info("Dropping existing user table")
            db.session.execute(text('DROP TABLE IF EXISTS "user" CASCADE'))
            db.session.commit()
        
        # Create all tables
        logger.info("Creating all tables")
        db.create_all()
        db.session.commit()
        logger.info("Migration completed successfully")
        
    except Exception as e:
        logger.error(f"Error during migration: {e}")
        db.session.rollback()
        raise

if __name__ == "__main__":
    with app.app_context():
        run_migration()