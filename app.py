import os
import logging
import sys
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase
from flask_cors import CORS
from werkzeug.serving import WSGIRequestHandler

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Configure Werkzeug to use HTTP/1.1
WSGIRequestHandler.protocol_version = "HTTP/1.1"

# Set up SQLAlchemy base class
class Base(DeclarativeBase):
    pass

# Initialize SQLAlchemy
db = SQLAlchemy(model_class=Base)

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key")

# Configure HTTP/1.1
app.config['SERVER_NAME'] = None  # Allow any hostname
app.config['PREFERRED_URL_SCHEME'] = 'http'
app.config['JSON_SORT_KEYS'] = False
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = False
app.config['JSONIFY_MIMETYPE'] = 'application/json'

# Configure database - handle both PostgreSQL and SQLite for local development
database_url = os.environ.get("DATABASE_URL")
logger.debug(f"Initial DATABASE_URL from environment: {database_url}")

# If DATABASE_URL is not provided, use SQLite as a fallback for local development
if not database_url:
    # Use SQLite file in the current directory
    database_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'postcode_distances.db')
    database_url = f"sqlite:///{database_path}"
    logger.warning(f"Database URL not found. Using SQLite: {database_url}")
    logger.warning("To use PostgreSQL, set the DATABASE_URL environment variable")
    logger.warning("Example: DATABASE_URL=postgresql://username:password@localhost:5432/dbname")
elif database_url.startswith("postgres://"):
    # Heroku-style URL - replace for SQLAlchemy 1.4+ compatibility
    database_url = database_url.replace("postgres://", "postgresql://", 1)
    logger.debug(f"Converted postgres:// to postgresql:// URL: {database_url}")

logger.debug(f"Final database URL being used: {database_url}")

app.config["SQLALCHEMY_DATABASE_URI"] = database_url
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Set engine options based on database type
if database_url.startswith("postgresql"):
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_recycle": 300,
        "pool_pre_ping": True,
        "pool_size": 10,
        "max_overflow": 20,
    }
    logger.debug("Using PostgreSQL configuration")
else:
    # Simpler config for SQLite
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_pre_ping": True,
    }
    logger.debug("Using SQLite configuration")

# Initialize the app with the extension
db.init_app(app)

with app.app_context():
    try:
        # Import models here to avoid circular imports
        import models
        # Create all database tables if they don't exist
        db.create_all()
        logger.debug("Database tables checked/created successfully")
    except Exception as e:
        logger.error(f"Error initializing database: {str(e)}")
        if "already exists" in str(e):
            logger.warning("Tables already exist, continuing...")
        else:
        logger.error("Please check your database configuration and ensure PostgreSQL is running")
        raise
