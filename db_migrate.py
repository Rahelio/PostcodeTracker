import os
import sys
from sqlalchemy import text
from app import app, db
from models import Journey, SavedLocation

"""
Simple database migration script to handle the addition of new columns to the Journey table
and create the SavedLocation table.
"""

def run_migration():
    print("Starting database migration...")
    
    with app.app_context():
        engine = db.engine
        inspector = db.inspect(engine)
        
        # Check if the journey table exists
        if 'journey' not in inspector.get_table_names():
            print("Error: Journey table doesn't exist. Running create_all...")
            db.create_all()
            print("Database tables created.")
            return
        
        # Check if we need to add the is_manual column
        journey_columns = [col['name'] for col in inspector.get_columns('journey')]
        cols_to_add = []
        
        if 'is_manual' not in journey_columns:
            cols_to_add.append("ALTER TABLE journey ADD COLUMN is_manual BOOLEAN DEFAULT FALSE")
        
        if 'start_location_id' not in journey_columns:
            cols_to_add.append("ALTER TABLE journey ADD COLUMN start_location_id INTEGER")
        
        if 'end_location_id' not in journey_columns:
            cols_to_add.append("ALTER TABLE journey ADD COLUMN end_location_id INTEGER")
        
        # Create the saved_location table if it doesn't exist
        if 'saved_location' not in inspector.get_table_names():
            print("Creating saved_location table...")
            SavedLocation.__table__.create(engine)
            print("SavedLocation table created.")
        
        # Add the columns to journey table
        if cols_to_add:
            print(f"Adding new columns to journey table: {cols_to_add}")
            try:
                with engine.begin() as conn:
                    for query in cols_to_add:
                        print(f"Running: {query}")
                        conn.execute(text(query))
            except Exception as e:
                print(f"Error during column addition: {e}")
                sys.exit(1)
            
            print("Successfully added new columns.")
        else:
            print("No schema changes needed.")
        
        # Add foreign key constraints if they don't exist
        if 'start_location_id' in journey_columns and 'end_location_id' in journey_columns:
            try:
                # Check if foreign keys already exist
                constraints = inspector.get_foreign_keys('journey')
                constraint_columns = [c['constrained_columns'] for c in constraints]
                
                if ['start_location_id'] not in constraint_columns:
                    print("Adding foreign key for start_location_id...")
                    with engine.begin() as conn:
                        conn.execute(text(
                            "ALTER TABLE journey ADD CONSTRAINT fk_journey_start_location "
                            "FOREIGN KEY (start_location_id) REFERENCES saved_location (id)"
                        ))
                
                if ['end_location_id'] not in constraint_columns:
                    print("Adding foreign key for end_location_id...")
                    with engine.begin() as conn:
                        conn.execute(text(
                            "ALTER TABLE journey ADD CONSTRAINT fk_journey_end_location "
                            "FOREIGN KEY (end_location_id) REFERENCES saved_location (id)"
                        ))
            except Exception as e:
                print(f"Error adding foreign key constraints: {e}")
                print("Continuing without foreign keys...")
        
        print("Migration completed successfully.")

if __name__ == "__main__":
    run_migration()