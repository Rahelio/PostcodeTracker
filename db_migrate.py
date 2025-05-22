import os
import sys
from sqlalchemy import text
from app import app, db
from models import Journey, SavedLocation
import logging

"""
Simple database migration script to handle the addition of new columns to the Journey table
and create the SavedLocation table.
"""

logger = logging.getLogger(__name__)

def run_migration():
    """Run database migrations for PostgreSQL."""
    try:
        # Drop the user table if it exists
        db.session.execute('DROP TABLE IF EXISTS "user" CASCADE')
        db.session.commit()
        logger.info("Dropped existing user table")
        
        # Create all tables
        db.create_all()
        logger.info("Created all tables with updated schema")
        
    except Exception as e:
        logger.error(f"Error during migration: {e}")
        db.session.rollback()
        raise

if __name__ == "__main__":
    run_migration()