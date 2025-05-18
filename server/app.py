from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_jwt_extended import JWTManager
import os
import logging
import sys
from datetime import timedelta

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configure CORS
CORS(app, resources={r"/api/*": {"origins": "*"}})

# JWT Configuration
app.config["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY", "dev-secret-key")
app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
jwt = JWTManager(app)

# Database Configuration
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    database_path = os.path.join(os.path.abspath(os.path.dirname(__file__)), '..', 'postcode_distances.db')
    database_url = f"sqlite:///{database_path}"
    logger.warning(f"Database URL not found. Using SQLite: {database_url}")
elif database_url.startswith("postgres://"):
    database_url = database_url.replace("postgres://", "postgresql://", 1)

app.config["SQLALCHEMY_DATABASE_URI"] = database_url
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

# Initialize SQLAlchemy
db = SQLAlchemy(app)

# Import and register blueprints
from api.auth import auth_bp
from api.postcodes import postcodes_bp

app.register_blueprint(auth_bp, url_prefix='/api/auth')
app.register_blueprint(postcodes_bp, url_prefix='/api/postcodes')

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=5000, debug=True) 