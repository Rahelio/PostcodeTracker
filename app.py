import os
import logging
from flask import Flask
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
DB_USER = os.environ.get('DB_USER', 'locator')
DB_PASSWORD = os.environ.get('DB_PASSWORD', 'Aberdeen24')
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'postcodetrackerdb')
POSTGRES_URI = f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'

app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', os.urandom(24))
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', POSTGRES_URI)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', os.urandom(24))
app.config['JWT_EXPIRATION_DELTA'] = timedelta(days=30)

# Initialize extensions
from database import db
db.init_app(app)
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
