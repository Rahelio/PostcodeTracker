import os
import logging
import sys
from flask import Flask, jsonify, make_response, request
from flask_cors import CORS
from flask_jwt_extended import JWTManager
from datetime import timedelta
from server.database import init_db
from dotenv import load_dotenv
from server.api.auth import auth_bp
from server.api.postcodes import postcodes_bp
from server.api.journeys import journeys_bp
from werkzeug.serving import WSGIRequestHandler

# Load environment variables from .env file
load_dotenv(os.path.join(os.path.dirname(__file__), '.env'))

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Force HTTP/1.1
WSGIRequestHandler.protocol_version = "HTTP/1.1"

def create_app():
    app = Flask(__name__)
    
    # Configure CORS
    CORS(app, resources={r"/api/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
        "supports_credentials": True,
        "max_age": 3600
    }})
    
    @app.after_request
    def after_request(response):
        # Log request details
        logger.debug(f"Request path: {request.path}")
        logger.debug(f"Request method: {request.method}")
        logger.debug(f"Response status: {response.status_code}")
        
        # Force HTTP/1.1
        response.headers['Connection'] = 'keep-alive'
        response.headers['Content-Type'] = 'application/json'
        response.headers['Server'] = 'PostcodeTracker/1.0'
        
        # Add security headers
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-XSS-Protection'] = '1; mode=block'
        
        # Add CORS headers
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        
        return response
    
    # Health check endpoint
    @app.route('/api/health')
    def health_check():
        logger.debug("Health check endpoint called")
        return jsonify({
            'status': 'healthy',
            'database': 'connected'
        }), 200
    
    # Root endpoint
    @app.route('/')
    def root():
        logger.debug("Root endpoint called")
        return jsonify({
            'message': 'Welcome to PostcodeTracker API',
            'version': '1.0'
        }), 200
    
    # JWT Configuration
    app.config["JWT_SECRET_KEY"] = os.environ.get("JWT_SECRET_KEY", "dev-secret-key")
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=12)
    jwt = JWTManager(app)
    
    # Initialize database
    init_db()
    
    # Import and register blueprints
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(postcodes_bp, url_prefix='/api/postcodes')
    app.register_blueprint(journeys_bp, url_prefix='/api/journeys')
    
    return app

app = create_app()

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=8000, debug=True) 