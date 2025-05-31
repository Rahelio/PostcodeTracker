import os
import sys
import sqlite3
from sqlalchemy import text, inspect
from app import app, db
from models import Journey, Postcode

"""
SQLite-specific migration script that handles the database structure update
by creating a new table with the updated schema and copying the data.
"""

def run_sqlite_migration():
    print("Starting SQLite database migration...")
    
    # Get the database path from app config
    db_url = app.config["SQLALCHEMY_DATABASE_URI"]
    if not db_url.startswith("sqlite:///"):
        print("This script is only for SQLite databases. Exiting.")
        sys.exit(1)
    
    # Extract the database path from the URL
    db_path = db_url.replace("sqlite:///", "")
    
    # Check if the database file exists
    if not os.path.exists(db_path):
        print(f"Database file {db_path} does not exist. Creating tables with SQLAlchemy...")
        with app.app_context():
            db.create_all()
        print("Database tables created.")
        return
    
    # Connect to the SQLite database
    print(f"Connecting to SQLite database at {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if the journey table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='journey'")
    if not cursor.fetchone():
        print("Journey table doesn't exist. Creating tables with SQLAlchemy...")
        conn.close()
        with app.app_context():
            db.create_all()
        print("Database tables created.")
        return
    
    # Check if the saved_location table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='saved_location'")
    if not cursor.fetchone():
        print("Creating saved_location table...")
        cursor.execute('''
        CREATE TABLE saved_location (
            id INTEGER PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            postcode VARCHAR(10) NOT NULL,
            latitude FLOAT,
            longitude FLOAT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
        ''')
        conn.commit()
        print("saved_location table created.")
    
    # Check if the journey table has the new columns
    cursor.execute("PRAGMA table_info(journey)")
    columns = [col[1] for col in cursor.fetchall()]
    
    # If we need to update the journey table
    if 'is_manual' not in columns or 'start_location_id' not in columns or 'end_location_id' not in columns:
        print("Detected missing columns in journey table. Creating new table with updated schema...")
        
        # Rename the old table
        cursor.execute("ALTER TABLE journey RENAME TO journey_old")
        
        # Create the new table with the updated schema
        cursor.execute('''
        CREATE TABLE journey (
            id INTEGER PRIMARY KEY,
            start_postcode VARCHAR(10) NOT NULL,
            end_postcode VARCHAR(10),
            start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
            end_time DATETIME,
            distance_miles FLOAT,
            is_manual BOOLEAN DEFAULT 0,
            start_location_id INTEGER,
            end_location_id INTEGER,
            FOREIGN KEY (start_location_id) REFERENCES saved_location (id),
            FOREIGN KEY (end_location_id) REFERENCES saved_location (id)
        )
        ''')
        
        # Copy data from the old table to the new one
        print("Copying data from old table to new table...")
        cursor.execute('''
        INSERT INTO journey (id, start_postcode, end_postcode, start_time, end_time, distance_miles)
        SELECT id, start_postcode, end_postcode, start_time, end_time, distance_miles FROM journey_old
        ''')
        
        # Drop the old table
        cursor.execute("DROP TABLE journey_old")
        
        # Commit the changes
        conn.commit()
        print("Journey table updated with new columns.")
    else:
        print("Journey table already has all required columns.")
    
    # Close the database connection
    conn.close()
    print("SQLite migration completed successfully.")

if __name__ == "__main__":
    run_sqlite_migration()