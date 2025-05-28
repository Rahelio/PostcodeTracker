import os
import sys
from pathlib import Path
from dotenv import load_dotenv, find_dotenv

# Print detailed system information
print("\n=== System Information ===")
print(f"Python version: {sys.version}")
print(f"Current working directory: {os.getcwd()}")
print(f"User running the script: {os.getenv('USER')}")
print(f"Home directory: {os.path.expanduser('~')}")

# Try multiple ways to find and load the .env file
print("\n=== Environment File Search ===")
env_paths = [
    os.path.join(os.getcwd(), '.env'),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'),
    os.path.join(os.path.expanduser('~'), '.env'),
    find_dotenv()
]

print("Searching for .env file in these locations:")
for path in env_paths:
    if path:
        print(f"- {path}: {'EXISTS' if os.path.exists(path) else 'NOT FOUND'}")
        if os.path.exists(path):
            print(f"  Permissions: {oct(os.stat(path).st_mode)[-3:]}")
            print(f"  Owner: {os.stat(path).st_uid}")
            print(f"  Group: {os.stat(path).st_gid}")

# Try to load the .env file
print("\n=== Loading Environment Variables ===")
dotenv_loaded = load_dotenv()
print(f"load_dotenv() returned: {dotenv_loaded}")

# Print all environment variables
print("\n=== Environment Variables ===")
print("DATABASE_URL:", os.environ.get("DATABASE_URL"))
print("PYTHONPATH:", os.environ.get("PYTHONPATH"))

# Try to manually read the .env file
print("\n=== Attempting to read .env file directly ===")
for path in env_paths:
    if path and os.path.exists(path):
        try:
            with open(path, 'r') as f:
                print(f"Contents of {path}:")
                for line in f:
                    if 'DATABASE_URL' in line:
                        print(f"Found DATABASE_URL line: {line.strip()}")
        except Exception as e:
            print(f"Error reading {path}: {str(e)}")

from app import app, db
from db_migrate import run_migration
from sqlite_migrate import run_sqlite_migration
from models import User, Journey, SavedLocation

"""
Unified migration script that chooses the appropriate migration strategy
based on the database type configured in the application.
"""

def run_appropriate_migration():
    print("\n=== Starting Migration ===")
    print("Checking database type...")
    
    db_url = app.config["SQLALCHEMY_DATABASE_URI"]
    print(f"Database URL from app config: {db_url}")
    
    with app.app_context():
    if db_url.startswith("sqlite:///"):
        print("SQLite database detected. Running SQLite-specific migration...")
        run_sqlite_migration()
    else:
        print("PostgreSQL database detected. Running standard migration...")
        run_migration()
    
    print("Migration complete. You can now restart your application.")

def init_db():
    """Initialize the database with all required tables."""
    with app.app_context():
        try:
            # Create all tables
            db.create_all()
            print("Database tables created successfully")
        except Exception as e:
            print(f"Error creating database tables: {e}")

if __name__ == "__main__":
    run_appropriate_migration()
    init_db()