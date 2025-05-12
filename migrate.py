import os
import sys
from app import app
from db_migrate import run_migration
from sqlite_migrate import run_sqlite_migration

"""
Unified migration script that chooses the appropriate migration strategy
based on the database type configured in the application.
"""

def run_appropriate_migration():
    print("Checking database type...")
    
    db_url = app.config["SQLALCHEMY_DATABASE_URI"]
    
    if db_url.startswith("sqlite:///"):
        print("SQLite database detected. Running SQLite-specific migration...")
        run_sqlite_migration()
    else:
        print("PostgreSQL database detected. Running standard migration...")
        run_migration()
    
    print("Migration complete. You can now restart your application.")

if __name__ == "__main__":
    run_appropriate_migration()