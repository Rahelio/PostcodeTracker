import os
import sys
from dotenv import load_dotenv

# Print current working directory and list all files
print("Current working directory:", os.getcwd())
print("Files in current directory:", os.listdir("."))

# Try to load .env file and print result
env_path = os.path.join(os.getcwd(), '.env')
print(f"Looking for .env file at: {env_path}")
print(f".env file exists: {os.path.exists(env_path)}")

# Load environment variables
load_dotenv()

# Print all environment variables
print("\nEnvironment variables:")
print("DATABASE_URL:", os.environ.get("DATABASE_URL"))
print("PYTHONPATH:", os.environ.get("PYTHONPATH"))
print("Current directory:", os.getcwd())

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
    print(f"Database URL from app config: {db_url}")
    
    if db_url.startswith("sqlite:///"):
        print("SQLite database detected. Running SQLite-specific migration...")
        run_sqlite_migration()
    else:
        print("PostgreSQL database detected. Running standard migration...")
        run_migration()
    
    print("Migration complete. You can now restart your application.")

if __name__ == "__main__":
    run_appropriate_migration()