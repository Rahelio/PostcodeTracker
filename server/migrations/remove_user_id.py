from sqlalchemy import create_engine
from sqlalchemy.sql import text

# Use the same database URL as in your application
DATABASE_URL = 'postgresql://locator:Aberdeen24@0.0.0.0:5432/postcodetrackerdb'

def run_migration():
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as connection:
        # Drop user_id column if it exists
        connection.execute(text("""
            ALTER TABLE saved_location 
            DROP COLUMN IF EXISTS user_id
        """))
        connection.commit()

if __name__ == '__main__':
    run_migration() 