import os
import logging
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from datetime import timedelta

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configuration
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', os.urandom(24))
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///postcode_tracker.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', os.urandom(24))
app.config['JWT_EXPIRATION_DELTA'] = timedelta(days=30)

# Initialize extensions
db = SQLAlchemy(app)
CORS(app, origins=["*"])  # Allow all origins for development

# Import models and routes after app initialization
from models import Journey, User
from routes import *

# Create tables
with app.app_context():
    db.create_all()
    logger.info("Database tables created successfully")

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8005))
    debug = os.environ.get('FLASK_ENV') == 'development'
    app.run(host='0.0.0.0', port=port, debug=debug)
