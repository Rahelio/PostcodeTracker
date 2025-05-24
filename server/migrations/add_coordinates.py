from sqlalchemy import create_engine, Float
from sqlalchemy.sql import text

# Use the same database URL as in your application
DATABASE_URL = 'postgresql://locator:Aberdeen24@0.0.0.0:5432/postcodetrackerdb'

def run_migration():
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as connection:
        # Add latitude and longitude columns
        connection.execute(text("""
            ALTER TABLE saved_location 
            ADD COLUMN IF NOT EXISTS latitude FLOAT,
            ADD COLUMN IF NOT EXISTS longitude FLOAT
        """))
        connection.commit()

if __name__ == '__main__':
    run_migration() 