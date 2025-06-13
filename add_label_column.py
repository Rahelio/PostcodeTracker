#!/usr/bin/env python3
"""
Migration script to add the 'label' column to the journeys table.
Run this script to update your database schema.
"""

import os
import sys
from sqlalchemy import create_engine, text
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def add_label_column():
    """Add the label column to the journeys table."""
    
    # Database configuration (same as app.py)
    DB_USER = os.environ.get('DB_USER', 'locator')
    DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Aberdeen24')
    DB_HOST = os.environ.get('DB_HOST', 'localhost')
    DB_NAME = os.environ.get('DB_NAME', 'postcodetrackerdb')
    POSTGRES_URI = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
    
    try:
        # Create database engine
        engine = create_engine(os.environ.get('DATABASE_URL', POSTGRES_URI))
        
        with engine.connect() as connection:
            # Check if the column already exists
            result = connection.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'journeys' AND column_name = 'label'
            """))
            
            if result.fetchone():
                logger.info("✅ Column 'label' already exists in 'journeys' table")
                return True
            
            # Add the label column
            logger.info("Adding 'label' column to 'journeys' table...")
            connection.execute(text("""
                ALTER TABLE journeys 
                ADD COLUMN label VARCHAR(100)
            """))
            connection.commit()
            
            logger.info("✅ Successfully added 'label' column to 'journeys' table")
            return True
            
    except Exception as e:
        logger.error(f"❌ Error adding label column: {e}")
        return False

if __name__ == "__main__":
    success = add_label_column()
    if success:
        print("✅ Database migration completed successfully!")
        print("🚀 You can now restart your server and the label functionality will work.")
    else:
        print("❌ Database migration failed!")
        sys.exit(1) 