import os
import logging
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.orm import DeclarativeBase

# Configure logging
logging.basicConfig(level=logging.DEBUG)

# Set up SQLAlchemy base class
class Base(DeclarativeBase):
    pass

# Initialize SQLAlchemy
db = SQLAlchemy(model_class=Base)

# Create Flask app
app = Flask(__name__)
app.secret_key = os.environ.get("SESSION_SECRET", "dev-secret-key")

# Configure database - handle both PostgreSQL and SQLite for local development
database_url = os.environ.get("DATABASE_URL")

# If DATABASE_URL is not provided, use SQLite as a fallback for local development
if not database_url:
    # Use SQLite file in the current directory
    database_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'postcode_distances.db')
    database_url = f"sqlite:///{database_path}"
    print(f"Database URL not found. Using SQLite: {database_url}")
elif database_url.startswith("postgres://"):
    # Heroku-style URL - replace for SQLAlchemy 1.4+ compatibility
    database_url = database_url.replace("postgres://", "postgresql://", 1)

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
else:
    # Simpler config for SQLite
    app.config["SQLALCHEMY_ENGINE_OPTIONS"] = {
        "pool_pre_ping": True,
    }

# Initialize the app with the extension
db.init_app(app)

with app.app_context():
    # Import models here to avoid circular imports
    import models
    # Create all database tables
    db.create_all()
