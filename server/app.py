import os
import logging
import sys
from flask import Flask, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from datetime import timedelta
from server.database import init_db
from dotenv import load_dotenv
from server.api.auth import auth_bp
from server.api.postcodes import postcodes_bp

# Load environment variables from .env file
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

def create_app():
    app = Flask(__name__)
    
    # Configure CORS
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
    # Health check endpoint
    @app.route('/api/health')
    def health_check():
        return jsonify({
            'status': 'healthy',
            'database': 'connected'
        }), 200
    
    # JWT Configuration
    app.config["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY", "dev-secret-key")
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=1)
    jwt = JWTManager(app)
    
    # Initialize database
    init_db()
    
    # Import and register blueprints
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(postcodes_bp, url_prefix='/api/postcodes')
    
    return app

app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) 