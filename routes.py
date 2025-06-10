import logging
from datetime import datetime, timedelta
from functools import wraps
from flask import request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
import jwt
from app import app
from database import db
from models import Journey, User
from postcode_service import PostcodeService

logger = logging.getLogger(__name__)

# JWT Token Management
def create_token(user_id: int) -> str:
    """Create a JWT token for the user."""
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
    }
    return jwt.encode(payload, app.config['JWT_SECRET_KEY'], algorithm='HS256')

def verify_token(token: str) -> int:
    """Verify JWT token and return user ID."""
    try:
        payload = jwt.decode(token, app.config['JWT_SECRET_KEY'], algorithms=['HS256'])
        return payload['user_id']
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def get_current_user():
    """Get current user from JWT token (optional authentication)."""
    auth_header = request.headers.get('Authorization')
    if not auth_header:
        return None
    
    try:
        token = auth_header.split(' ')[1]  # Remove 'Bearer ' prefix
        user_id = verify_token(token)
        if user_id:
            return User.query.get(user_id)
    except (IndexError, AttributeError):
        pass
    
    return None

def require_auth(f):
    """Decorator to require authentication for endpoints."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        current_user = get_current_user()
        if not current_user:
            return jsonify({
                'success': False, 
                'message': 'Authentication required. Please log in.'
            }), 401
        return f(current_user, *args, **kwargs)
    return decorated_function

# API Routes
@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        'success': True,
        'message': 'PostcodeTracker API is running',
        'timestamp': datetime.utcnow().isoformat()
    })

@app.route('/api/debug/user-count', methods=['GET'])
def debug_user_count():
    """Debug endpoint to check user count."""
    try:
        user_count = User.query.count()
        return jsonify({
            'success': True,
            'user_count': user_count,
            'timestamp': datetime.utcnow().isoformat()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/auth/register', methods=['POST'])
def register():
    """Register a new user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'message': 'No data provided'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        
        # Validation
        if not username or not password:
            return jsonify({'success': False, 'message': 'Username and password are required'}), 400
        
        if len(username) < 3:
            return jsonify({'success': False, 'message': 'Username must be at least 3 characters long'}), 400
        
        if len(password) < 6:
            return jsonify({'success': False, 'message': 'Password must be at least 6 characters long'}), 400
        
        # Check if user exists
        if User.query.filter_by(username=username).first():
            return jsonify({'success': False, 'message': 'Username already exists'}), 409
        
        # Create user
        password_hash = generate_password_hash(password)
        user = User(username=username, password_hash=password_hash)
        db.session.add(user)
        db.session.commit()
        
        # Create token
        token = create_token(user.id)
        
        logger.info(f"User {username} registered successfully")
        
        return jsonify({
            'success': True,
            'message': 'User registered successfully',
            'token': token,
            'user': user.to_dict()
        }), 201
        
    except Exception as e:
        logger.error(f"Registration error: {e}")
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
        
        response_data = {
            'success': True,
            'message': 'Login successful',
            'token': token,
            'user': user.to_dict()
        }
        
        logger.info(f"User {username} logged in successfully")
        logger.info(f"Login response: {response_data}")
        
        return jsonify(response_data)
        
    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({'success': False, 'message': 'Login failed'}), 500

@app.route('/api/auth/profile', methods=['GET'])
@require_auth
def get_profile(current_user):
    """Get user profile information."""
    try:
        # Get user's journey statistics
        total_journeys = Journey.query.filter_by(user_id=current_user.id).count()
        completed_journeys = Journey.query.filter_by(user_id=current_user.id).filter(Journey.end_time.isnot(None)).count()
        total_distance = db.session.query(db.func.sum(Journey.distance_miles)).filter_by(user_id=current_user.id).scalar() or 0
        
        profile_data = current_user.to_dict()
        profile_data.update({
            'total_journeys': total_journeys,
            'completed_journeys': completed_journeys,
            'total_distance_miles': round(total_distance, 2)
        })
        
        return jsonify({
            'success': True,
            'data': profile_data
        })
        
    except Exception as e:
        logger.error(f"Error getting profile for user {current_user.username}: {e}")
        return jsonify({'success': False, 'message': 'Failed to get profile'}), 500

@app.route('/api/auth/logout', methods=['POST'])
@require_auth
def logout(current_user):
    """Logout user (client should delete token)."""
    logger.info(f"User {current_user.username} logged out")
    return jsonify({
        'success': True,
        'message': 'Logged out successfully'
    })

@app.route('/api/journey/start', methods=['POST'])
@require_auth
def start_journey(current_user):
    """Start a new journey using GPS coordinates. Requires authentication."""
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
        
        # Check for active journey for this user
        active_journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
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
        
        # Create new journey for this user
        journey = Journey(
            start_postcode=start_postcode,
            start_latitude=lat,
            start_longitude=lon,
            user_id=current_user.id
        )
        db.session.add(journey)
        db.session.commit()
        
        logger.info(f"User {current_user.username} started journey {journey.id} with postcode {start_postcode}")
        
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
@require_auth
def end_journey(current_user):
    """End the active journey. Requires authentication."""
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
        
        # Find active journey for this user
        journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
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
        journey.end_latitude = lat
        journey.end_longitude = lon
        journey.end_time = datetime.utcnow()
        journey.distance_miles = distance
        
        db.session.commit()
        
        logger.info(f"Journey {journey.id} ended with postcode {end_postcode}, distance: {distance}")
        
        return jsonify({
            'success': True,
            'message': 'Journey ended successfully',
            'journey': journey.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error ending journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': 'Failed to end journey'}), 500

@app.route('/api/journey/active', methods=['GET'])
@require_auth
def get_active_journey(current_user):
    """Get the current active journey for the authenticated user."""
    try:
        journey = Journey.query.filter_by(user_id=current_user.id, end_time=None).first()
        
        if journey:
            return jsonify({
                'success': True,
                'active': True,
                'journey': journey.to_dict()
            })
        else:
            return jsonify({
                'success': True,
                'active': False,
                'journey': None
            })
            
    except Exception as e:
        logger.error(f"Error getting active journey for user {current_user.username}: {e}")
        return jsonify({'success': False, 'message': 'Failed to get active journey'}), 500

@app.route('/api/journeys', methods=['GET'])
@require_auth
def get_journeys(current_user):
    """Get all journeys for the authenticated user."""
    try:
        journeys = Journey.query.filter_by(user_id=current_user.id).order_by(Journey.start_time.desc()).all()
        
        logger.info(f"Retrieved {len(journeys)} journeys for user {current_user.username}")
        
        return jsonify({
            'success': True,
            'journeys': [journey.to_dict() for journey in journeys]
        })
        
    except Exception as e:
        logger.error(f"Error getting journeys for user {current_user.username}: {e}")
        return jsonify({'success': False, 'message': 'Failed to get journeys'}), 500

@app.route('/api/postcodes', methods=['GET'])
def get_postcodes():
    """Legacy endpoint for postcodes - returns empty list since we removed postcode management."""
    return jsonify([])

@app.route('/api/postcode/from-coordinates', methods=['GET'])
def get_postcode_from_coordinates():
    """Get UK postcode from coordinates."""
    try:
        latitude = request.args.get('latitude')
        longitude = request.args.get('longitude')
        
        if not latitude or not longitude:
            return jsonify({
                'success': False,
                'message': 'Latitude and longitude parameters are required'
            }), 400
        
        try:
            lat = float(latitude)
            lon = float(longitude)
        except (ValueError, TypeError):
            return jsonify({
                'success': False,
                'message': 'Invalid latitude or longitude format'
            }), 400
        
        postcode = PostcodeService.get_postcode_from_coordinates(lat, lon)
        
        if postcode:
            return jsonify({
                'success': True,
                'postcode': postcode
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Could not determine postcode for the given coordinates'
            }), 404
            
    except Exception as e:
        logger.error(f"Error getting postcode from coordinates: {e}")
        return jsonify({'success': False, 'message': 'Failed to get postcode'}), 500 