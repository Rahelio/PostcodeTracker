from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Boolean, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Get database URL from environment variable
DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///postcode_tracker.db')

# Create engine and session
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
session = Session()

def table_exists(table_name):
    """Check if a table exists in the database"""
    result = engine.execute(f'''
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='{table_name}'
    ''')
    return result.fetchone() is not None

def upgrade():
    # Check if journeys table already exists
    if not table_exists('journeys'):
        print("Creating journeys table...")
        # Create journeys table
        engine.execute('''
            CREATE TABLE journeys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                start_postcode VARCHAR NOT NULL,
                end_postcode VARCHAR,
                distance FLOAT,
                start_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                end_time DATETIME,
                is_active BOOLEAN DEFAULT 1,
                is_manual BOOLEAN DEFAULT 0,
                start_location_id INTEGER,
                end_location_id INTEGER,
                FOREIGN KEY (start_location_id) REFERENCES postcodes (id),
                FOREIGN KEY (end_location_id) REFERENCES postcodes (id)
            )
        ''')
        session.commit()
        print("Journeys table created successfully!")
    else:
        print("Journeys table already exists. No changes made to preserve existing data.")

def downgrade():
    """Only use this if you really want to delete the journeys table"""
    if table_exists('journeys'):
        print("WARNING: This will delete all journey data!")
        response = input("Are you sure you want to continue? (yes/no): ")
        if response.lower() == 'yes':
            engine.execute('DROP TABLE journeys')
            session.commit()
            print("Journeys table deleted.")
        else:
            print("Operation cancelled.")
    else:
        print("Journeys table does not exist.")

if __name__ == '__main__':
    upgrade() 