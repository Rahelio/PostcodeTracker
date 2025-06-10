from flask import request, jsonify
from datetime import datetime, timedelta
import logging
import jwt
import os
from werkzeug.security import generate_password_hash, check_password_hash

from app import app, db
from models import Journey, User
from postcode_service import PostcodeService

logger = logging.getLogger(__name__)

# JWT Helper Functions
def create_token(user_id: int) -> str:
    """Create a JWT token for the user."""
    try:
        payload = {
            'user_id': user_id,
            'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
        }
        return jwt.encode(payload, app.config['JWT_SECRET_KEY'], algorithm='HS256')
    except Exception as e:
        logger.error(f"Error creating token: {e}")
        raise

def verify_token(token: str) -> int:
    """Verify a JWT token and return user_id."""
    try:
        payload = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        logger.warning("Token has expired")
        raise
    except jwt.InvalidTokenError:
        logger.warning("Invalid token")
        raise

def get_current_user():
    """Get current user from JWT token."""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        return None
    
    token = auth_header.split(' ')[1]
    try:
        user_id = verify_token(token)
        return User.query.get(user_id)
    except:
        return None

# API Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'version': '2.0'
    })

@app.route('/api/auth/register', methods=['POST'])
def register():
    """Register a new user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        
        if not username or not password:
            return jsonify({'success': False, 'message': 'Username and password are required'}), 400
        
        if len(username) < 3:
            return jsonify({'success': False, 'message': 'Username must be at least 3 characters'}), 400
        
        if len(password) < 6:
            return jsonify({'success': False, 'message': 'Password must be at least 6 characters'}), 400
        
        # Check if user already exists
        if User.query.filter_by(username=username).first():
            return jsonify({'success': False, 'message': 'Username already exists'}), 409
        
        # Create new user
        password_hash = generate_password_hash(password)
        user = User(username=username, password_hash=password_hash)
        db.session.add(user)
        db.session.commit()
        
        # Create token
        token = create_token(user.id)
        
        return jsonify({
            'success': True,
            'message': 'User registered successfully',
            'token': token,
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        logger.error(f"Error in register: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Registration failed'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """Login user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        
        if not username or not password:
            return jsonify({'success': False, 'message': 'Username and password are required'}), 400
        
        # Find user
        user = User.query.filter_by(username=username).first()
        if not user or not check_password_hash(user.password_hash, password):
            return jsonify({'success': False, 'message': 'Invalid username or password'}), 401
        
        # Create token
        token = create_token(user.id)
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error in login: {e}")
        return jsonify({'success': False, 'message': 'Login failed'}), 500

@app.route('/api/journey/start', methods=['POST'])
def start_journey():
    """Start a new journey."""
    try:
        # Get current user (optional for now)
        current_user = get_current_user()
        
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if latitude is None or longitude is None:
            return jsonify({'success': False, 'message': 'Latitude and longitude are required'}), 400
        
        # Validate coordinates
        try:
            lat = float(latitude)
            lon = float(longitude)
            if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
                raise ValueError("Invalid coordinate range")
        except (ValueError, TypeError):
            return jsonify({'success': False, 'message': 'Invalid coordinates'}), 400
        
        # Check for active journey for this user
        if current_user:
            active_journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
        else:
            active_journey = Journey.query.filter_by(user_id=None, end_time=None).first()
        
        if active_journey:
            return jsonify({
                'success': False, 
                'message': 'You already have an active journey'
            }), 400
        
        # Get postcode from coordinates
        start_postcode = PostcodeService.get_postcode_from_coordinates(lat, lon)
        if not start_postcode:
            return jsonify({
                'success': False, 
                'message': 'Could not determine UK postcode for your location'
            }), 400
        
        # Create new journey
        journey = Journey(
            start_postcode=start_postcode,
            user_id=current_user.id if current_user else None
        )
        db.session.add(journey)
        db.session.commit()
        
        logger.info(f"Journey {journey.id} started with postcode {start_postcode}")
        
        return jsonify({
            'success': True,
            'message': 'Journey started successfully',
            'journey': journey.to_dict()
        }), 201
        
    except Exception as e:
        logger.error(f"Error starting journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Failed to start journey'}), 500

@app.route('/api/journey/end', methods=['POST'])
def end_journey():
    """End the active journey."""
    try:
        # Get current user (optional for now)
        current_user = get_current_user()
        
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if latitude is None or longitude is None:
            return jsonify({'success': False, 'message': 'Latitude and longitude are required'}), 400
        
        # Validate coordinates
        try:
            lat = float(latitude)
            lon = float(longitude)
            if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
                raise ValueError("Invalid coordinate range")
        except (ValueError, TypeError):
            return jsonify({'success': False, 'message': 'Invalid coordinates'}), 400
        
        # Find active journey
        if current_user:
            journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
        else:
            journey = Journey.query.filter_by(user_id=None, end_time=None).first()
        
        if not journey:
            return jsonify({'success': False, 'message': 'No active journey found'}), 404
        
        # Get end postcode from coordinates
        end_postcode = PostcodeService.get_postcode_from_coordinates(lat, lon)
        if not end_postcode:
            return jsonify({
                'success': False, 
                'message': 'Could not determine UK postcode for your location'
            }), 400
        
        # Calculate distance
        distance = PostcodeService.calculate_distance(journey.start_postcode, end_postcode)
        if distance is None:
            logger.warning(f"Could not calculate distance between {journey.start_postcode} and {end_postcode}")
            # Continue anyway - distance calculation failure shouldn't stop journey completion
        
        # Update journey
        journey.end_postcode = end_postcode
        journey.end_time = datetime.utcnow()
        journey.distance_miles = distance
        db.session.commit()
        
        logger.info(f"Journey {journey.id} completed: {journey.start_postcode} to {end_postcode}, {distance} miles")
        
        return jsonify({
            'success': True,
            'message': 'Journey completed successfully',
            'journey': journey.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error ending journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Failed to end journey'}), 500

@app.route('/api/journey/active', methods=['GET'])
def get_active_journey():
    """Get the current active journey."""
    try:
        # Get current user (optional for now)
        current_user = get_current_user()
        
        if current_user:
            journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
        else:
            journey = Journey.query.filter_by(user_id=None, end_time=None).first()
        
        if journey:
            return jsonify({
                'success': True,
                'active': True,
                'journey': journey.to_dict()
            })
        else:
            return jsonify({
                'success': True,
                'active': False
            })
            
    except Exception as e:
        logger.error(f"Error getting active journey: {e}")
        return jsonify({'success': False, 'message': 'Failed to get active journey'}), 500

@app.route('/api/journeys', methods=['GET'])
def get_journeys():
    """Get all completed journeys."""
    try:
        # Get current user (optional for now)
        current_user = get_current_user()
        
        if current_user:
            journeys = Journey.query.filter_by(user_id=current_user.id)\
                .filter(Journey.end_time.isnot(None))\
                .order_by(Journey.end_time.desc()).all()
        else:
            journeys = Journey.query.filter_by(user_id=None)\
                .filter(Journey.end_time.isnot(None))\
                .order_by(Journey.end_time.desc()).all()
        
        return jsonify({
            'success': True,
            'journeys': [journey.to_dict() for journey in journeys]
        })
        
    except Exception as e:
        logger.error(f"Error getting journeys: {e}")
        return jsonify({'success': False, 'message': 'Failed to get journeys'}), 500

@app.route('/api/postcode/from-coordinates', methods=['POST'])
def get_postcode_from_coordinates():
    """Get postcode from coordinates."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if latitude is None or longitude is None:
            return jsonify({'success': False, 'message': 'Latitude and longitude are required'}), 400
        
        # Validate coordinates
        try:
            lat = float(latitude)
            lon = float(longitude)
            if not (-90 <= lat <= 90) or not (-180 <= lon <= 180):
                raise ValueError("Invalid coordinate range")
        except (ValueError, TypeError):
            return jsonify({'success': False, 'message': 'Invalid coordinates'}), 400
        
        # Get postcode
        postcode = PostcodeService.get_postcode_from_coordinates(lat, lon)
        if postcode:
            return jsonify({
                'success': True,
                'postcode': postcode
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Could not find UK postcode for these coordinates'
            }), 404
            
    except Exception as e:
        logger.error(f"Error getting postcode from coordinates: {e}")
        return jsonify({'success': False, 'message': 'Failed to get postcode'}), 500 