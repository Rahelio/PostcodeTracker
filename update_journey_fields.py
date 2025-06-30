#!/usr/bin/env python3
"""
Migration script to update journey fields in the journeys table.
- Remove 'label' column
- Add 'client_name' column (VARCHAR(100))
- Add 'recharge_to_client' column (BOOLEAN)
- Add 'description' column (TEXT)

Run this script to update your database schema.
"""

import os
import sys
from sqlalchemy import create_engine, text
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def update_journey_fields():
    """Update the journey fields in the journeys table."""
    
    # Database configuration (same as app.py)
    DB_USER = os.environ.get('DB_USER', 'locator')
    DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Aberdeen24')
    DB_HOST = os.environ.get('DB_HOST', 'localhost')
    DB_NAME = os.environ.get('DB_NAME', 'postcodetrackerdb')
    POSTGRES_URI = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
    
    try:
        # Create database engine
        engine = create_engine(os.environ.get('DATABASE_URL', POSTGRES_URI))
        
        with engine.begin() as connection:
            # Check current schema
            result = connection.execute(text("""
                SELECT column_name 
                FROM information_schema.columns 
                WHERE table_name = 'journeys'
                ORDER BY column_name
            """))
            
            existing_columns = [row[0] for row in result.fetchall()]
            logger.info(f"Current columns in journeys table: {existing_columns}")
            
            # Add new columns if they don't exist
            if 'client_name' not in existing_columns:
                logger.info("Adding 'client_name' column...")
                connection.execute(text("""
                    ALTER TABLE journeys 
                    ADD COLUMN client_name VARCHAR(100)
                """))
            else:
                logger.info("✅ Column 'client_name' already exists")
            
            if 'recharge_to_client' not in existing_columns:
                logger.info("Adding 'recharge_to_client' column...")
                connection.execute(text("""
                    ALTER TABLE journeys 
                    ADD COLUMN recharge_to_client BOOLEAN
                """))
            else:
                logger.info("✅ Column 'recharge_to_client' already exists")
            
            if 'description' not in existing_columns:
                logger.info("Adding 'description' column...")
                connection.execute(text("""
                    ALTER TABLE journeys 
                    ADD COLUMN description TEXT
                """))
            else:
                logger.info("✅ Column 'description' already exists")
            
            # Remove label column if it exists
            if 'label' in existing_columns:
                logger.info("Removing 'label' column...")
                connection.execute(text("""
                    ALTER TABLE journeys 
                    DROP COLUMN label
                """))
            else:
                logger.info("✅ Column 'label' already removed")
            
            logger.info("✅ Successfully updated journey fields in 'journeys' table")
            return True
            
    except Exception as e:
        logger.error(f"❌ Error updating journey fields: {e}")
        return False

if __name__ == "__main__":
    success = update_journey_fields()
    if success:
        print("✅ Database migration completed successfully!")
        print("🚀 You can now restart your server and the new journey fields will work.")
    else:
        print("❌ Database migration failed!")
        sys.exit(1) 