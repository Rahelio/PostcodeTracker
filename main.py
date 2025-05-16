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
from routes import *

if __name__ == "__main__":
    app.run(host="", port=4999, debug=True)
