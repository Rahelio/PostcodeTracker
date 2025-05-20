import os
import sys
import logging
from dotenv import load_dotenv
from werkzeug.serving import run_simple

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Print current working directory and list all files
logger.info("Current working directory: %s", os.getcwd())
logger.info("Files in current directory: %s", os.listdir("."))

# Try to load .env file and print result
env_path = os.path.join(os.getcwd(), '.env')
logger.info("Looking for .env file at: %s", env_path)
logger.info(".env file exists: %s", os.path.exists(env_path))

# Load environment variables
load_dotenv()

# Print all environment variables
logger.info("Environment variables loaded")
logger.debug("DATABASE_URL: %s", os.environ.get("DATABASE_URL"))
logger.debug("PYTHONPATH: %s", os.environ.get("PYTHONPATH"))

from app import app
from routes import *

if __name__ == "__main__":
    logger.info("Starting Flask development server on port 5319")
    run_simple(
        '0.0.0.0',
        5319,
        app,
        use_reloader=True,
        use_debugger=True,
        use_evalex=True,
        threaded=True
    )
