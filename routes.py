from flask import render_template, request, jsonify, flash, redirect, url_for, send_file, make_response
from datetime import datetime, timedelta
import logging
import json
import io
import pandas as pd
import tempfile
import csv
from app import app, db
from models import Journey, SavedLocation, User
from postcode_service import PostcodeService
from export_util import export_to_csv, export_to_excel, get_journey_data
from werkzeug.security import generate_password_hash, check_password_hash
import jwt

logger = logging.getLogger(__name__)

# Add JWT configuration
app.config['SECRET_KEY'] = 'your-secret-key'  # Change this to a secure secret key
app.config['JWT_EXPIRATION_DELTA'] = timedelta(days=1)

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint for monitoring."""
    logger.info(f"Health check request received from: {request.remote_addr}")
    logger.info(f"Request headers: {dict(request.headers)}")
    
    response = make_response(jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'client_ip': request.remote_addr
    }))
    response.headers['Content-Type'] = 'application/json'
    response.headers['Server'] = 'Flask/1.0'
    response.headers['Connection'] = 'keep-alive'
    response.headers['Access-Control-Allow-Origin'] = '*'  # Allow CORS
    return response

@app.route('/')
def index():
    """Render the main page with journey form."""
    # Check for active journey
    active_journey = Journey.query.filter_by(end_time=None).first()
    return render_template('index.html', active_journey=active_journey)

@app.route('/history')
def history():
    """Render the journey history page."""
    # Get all completed journeys, ordered by most recent first
    journeys = Journey.query.filter(Journey.end_time.isnot(None)).order_by(Journey.end_time.desc()).all()
    return render_template('history.html', journeys=journeys)

@app.route('/api/journey/start', methods=['POST'])
def start_journey():
    """API endpoint to start a new journey."""
    try:
        data = request.get_json()
        start_postcode = data.get('start_postcode', '').strip().upper().replace(" ", "")
        
        # Validate postcode
        if not PostcodeService.validate_postcode(start_postcode):
            return jsonify({'success': False, 'message': 'Invalid UK postcode format'}), 400
            
        # Check if there's already an active journey
        active_journey = Journey.query.filter_by(end_time=None).first()
        if active_journey:
            return jsonify({
                'success': False, 
                'message': 'You already have an active journey in progress'
            }), 400
            
        # Create new journey
        journey = Journey(start_postcode=start_postcode)
        db.session.add(journey)
        db.session.commit()
        
        return jsonify({
            'success': True, 
            'message': 'Journey started successfully',
            'journey': journey.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error starting journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/journey/end', methods=['POST'])
def end_journey():
    """API endpoint to end an active journey."""
    try:
        data = request.get_json()
        end_postcode = data.get('end_postcode', '').strip().upper().replace(" ", "")
        
        # Validate postcode
        if not PostcodeService.validate_postcode(end_postcode):
            return jsonify({'success': False, 'message': 'Invalid UK postcode format'}), 400
            
        # Find active journey
        journey = Journey.query.filter_by(end_time=None).first()
        if not journey:
            return jsonify({
                'success': False, 
                'message': 'No active journey found'
            }), 404
            
        # Calculate distance
        distance = PostcodeService.calculate_distance(journey.start_postcode, end_postcode)
        if distance is None:
            return jsonify({
                'success': False, 
                'message': 'Could not calculate distance between postcodes'
            }), 400
            
        # Update journey
        journey.end_postcode = end_postcode
        journey.end_time = datetime.utcnow()
        journey.distance_miles = distance
        db.session.commit()
        
        return jsonify({
            'success': True, 
            'message': 'Journey completed successfully',
            'journey': journey.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error ending journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/journey/active', methods=['GET'])
def get_active_journey():
    """API endpoint to get the active journey (if any)."""
    try:
        journey = Journey.query.filter_by(end_time=None).first()
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
        logger.error(f"Error fetching active journey: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/journeys', methods=['GET'])
def get_journeys():
    """API endpoint to get all completed journeys."""
    try:
        journeys = Journey.query.filter(Journey.end_time.isnot(None)).order_by(Journey.end_time.desc()).all()
        return jsonify({
            'success': True,
            'journeys': [journey.to_dict() for journey in journeys]
        })
    except Exception as e:
        logger.error(f"Error fetching journeys: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/postcode/from-coordinates', methods=['POST'])
def get_postcode_from_coordinates():
    """API endpoint to convert coordinates to a UK postcode."""
    try:
        data = request.get_json()
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        
        if latitude is None or longitude is None:
            return jsonify({
                'success': False, 
                'message': 'Both latitude and longitude are required'
            }), 400
        
        # Log the coordinates received
        logger.info(f"Received coordinates: lat={latitude}, lon={longitude}")
        
        # Get postcode from coordinates
        postcode = PostcodeService.get_postcode_from_coordinates(latitude, longitude)
        
        if postcode:
            return jsonify({
                'success': True,
                'postcode': postcode
            })
        else:
            return jsonify({
                'success': False,
                'message': 'Could not find a UK postcode for these coordinates'
            }), 404
            
    except Exception as e:
        logger.error(f"Error converting coordinates to postcode: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/journeys/delete', methods=['POST'])
def delete_journeys():
    """API endpoint to delete selected journeys."""
    try:
        data = request.get_json()
        journey_ids = data.get('journey_ids', [])
        
        # Log delete request
        logger.info(f"Delete request for journey_ids: {journey_ids}")
        
        # Convert journey_ids to integers if they are strings
        if journey_ids:
            try:
                journey_ids = [int(id) for id in journey_ids]
            except ValueError:
                return jsonify({
                    'success': False,
                    'message': 'Invalid journey ID format'
                }), 400
                
            # Delete the journeys
            deleted_count = Journey.query.filter(Journey.id.in_(journey_ids)).delete(synchronize_session=False)
            db.session.commit()
            
            return jsonify({
                'success': True,
                'message': f'Successfully deleted {deleted_count} journeys',
                'deleted_count': deleted_count
            })
        else:
            return jsonify({
                'success': False,
                'message': 'No journey IDs provided'
            }), 400
            
    except Exception as e:
        logger.error(f"Error deleting journeys: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/journeys/export/<format_type>', methods=['POST'])
def export_journeys(format_type):
    """API endpoint to export selected journeys in CSV or Excel format."""
    try:
        data = request.get_json()
        journey_ids = data.get('journey_ids', [])
        
        # Normalize format type
        export_format = format_type.lower()
        
        # Log export request
        logger.info(f"Export request: format={export_format}, journey_ids={journey_ids}")
        
        # Validate format
        if export_format not in ['csv', 'excel']:
            return jsonify({
                'success': False,
                'message': 'Invalid export format. Supported formats: csv, excel'
            }), 400
        
        # Convert journey_ids to integers if they are strings
        if journey_ids:
            try:
                journey_ids = [int(id) for id in journey_ids]
            except ValueError:
                return jsonify({
                    'success': False,
                    'message': 'Invalid journey ID format'
                }), 400
        
        # Generate export file
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        if export_format == 'csv':
            # For CSV, create a file and return it
            from export_util import get_journey_data as get_data
            journey_data = get_data(journey_ids)
            
            if not journey_data:
                return jsonify({
                    'success': False,
                    'message': 'No journey data available for export'
                }), 404
                
            # Create a temporary file
            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.csv')
            filename = f"journey_history_{timestamp}.csv"
            
            # Write CSV data
            import csv
            with open(temp_file.name, 'w', newline='') as f:
                fieldnames = journey_data[0].keys()
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(journey_data)
            
            return send_file(
                temp_file.name,
                as_attachment=True,
                download_name=filename,
                mimetype='text/csv'
            )
            
        else:  # excel
            # For Excel, create a file and return it
            from export_util import get_journey_data as get_data
            
            journey_data = get_data(journey_ids)
            
            if not journey_data:
                return jsonify({
                    'success': False,
                    'message': 'No journey data available for export'
                }), 404
                
            # Create a temporary file
            temp_file = tempfile.NamedTemporaryFile(delete=False, suffix='.xlsx')
            filename = f"journey_history_{timestamp}.xlsx"
            
            # Convert to DataFrame and save to Excel
            df = pd.DataFrame(journey_data)
            df.to_excel(temp_file.name, sheet_name='Journey History', index=False)
            
            return send_file(
                temp_file.name,
                as_attachment=True,
                download_name=filename,
                mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            )
            
    except Exception as e:
        logger.error(f"Error exporting journeys: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

# Routes for saved locations
@app.route('/locations')
def locations():
    """Render the saved locations page."""
    locations = SavedLocation.query.order_by(SavedLocation.name).all()
    return render_template('locations.html', locations=locations)

@app.route('/api/locations', methods=['GET'])
def get_locations():
    """API endpoint to get all saved locations."""
    try:
        locations = SavedLocation.query.order_by(SavedLocation.name).all()
        return jsonify({
            'success': True,
            'locations': [location.to_dict() for location in locations]
        })
    except Exception as e:
        logger.error(f"Error fetching locations: {e}")
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/locations', methods=['POST'])
def add_location():
    """API endpoint to add a new saved location."""
    try:
        data = request.get_json()
        name = data.get('name', '').strip()
        postcode = data.get('postcode', '').strip().upper().replace(" ", "")
        
        # Validate data
        if not name:
            return jsonify({'success': False, 'message': 'Location name is required'}), 400
            
        if not postcode:
            return jsonify({'success': False, 'message': 'Postcode is required'}), 400
            
        # Validate postcode
        if not PostcodeService.validate_postcode(postcode):
            return jsonify({'success': False, 'message': 'Invalid UK postcode format'}), 400
            
        # Check if location with same name already exists
        existing = SavedLocation.query.filter_by(name=name).first()
        if existing:
            return jsonify({'success': False, 'message': f'A location named "{name}" already exists'}), 400
            
        # Create new location
        location = SavedLocation(name=name, postcode=postcode)
        db.session.add(location)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Location saved successfully',
            'location': location.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error adding location: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/locations/<int:location_id>', methods=['PUT'])
def update_location(location_id):
    """API endpoint to update a saved location."""
    try:
        location = SavedLocation.query.get(location_id)
        if not location:
            return jsonify({'success': False, 'message': 'Location not found'}), 404
            
        data = request.get_json()
        name = data.get('name', '').strip()
        postcode = data.get('postcode', '').strip().upper().replace(" ", "")
        
        # Validate data
        if not name:
            return jsonify({'success': False, 'message': 'Location name is required'}), 400
            
        if not postcode:
            return jsonify({'success': False, 'message': 'Postcode is required'}), 400
            
        # Validate postcode
        if not PostcodeService.validate_postcode(postcode):
            return jsonify({'success': False, 'message': 'Invalid UK postcode format'}), 400
            
        # Check if another location with the same name exists
        existing = SavedLocation.query.filter(SavedLocation.name == name, SavedLocation.id != location_id).first()
        if existing:
            return jsonify({'success': False, 'message': f'A different location named "{name}" already exists'}), 400
            
        # Update location
        location.name = name
        location.postcode = postcode
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Location updated successfully',
            'location': location.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error updating location: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/locations/<int:location_id>', methods=['DELETE'])
def delete_location(location_id):
    """API endpoint to delete a saved location."""
    try:
        location = SavedLocation.query.get(location_id)
        if not location:
            return jsonify({'success': False, 'message': 'Location not found'}), 404
            
        # Check if location is used in any journeys
        journeys_start = Journey.query.filter_by(start_location_id=location_id).count()
        journeys_end = Journey.query.filter_by(end_location_id=location_id).count()
        
        if journeys_start > 0 or journeys_end > 0:
            return jsonify({
                'success': False, 
                'message': f'Cannot delete location that is used in {journeys_start + journeys_end} journeys'
            }), 400
            
        # Delete location
        db.session.delete(location)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Location deleted successfully'
        })
        
    except Exception as e:
        logger.error(f"Error deleting location: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

# Manual journey routes
@app.route('/manual-journey')
def manual_journey():
    """Render the manual journey page."""
    locations = SavedLocation.query.order_by(SavedLocation.name).all()
    return render_template('manual_journey.html', locations=locations)

@app.route('/api/journey/manual', methods=['POST'])
def create_manual_journey():
    """API endpoint to create a manual journey between saved locations."""
    try:
        data = request.get_json()
        start_location_id = data.get('start_location_id')
        end_location_id = data.get('end_location_id')
        
        # Validate data
        if not start_location_id:
            return jsonify({'success': False, 'message': 'Start location is required'}), 400
            
        if not end_location_id:
            return jsonify({'success': False, 'message': 'End location is required'}), 400
            
        # Get locations
        start_location = SavedLocation.query.get(start_location_id)
        end_location = SavedLocation.query.get(end_location_id)
        
        if not start_location:
            return jsonify({'success': False, 'message': 'Start location not found'}), 404
            
        if not end_location:
            return jsonify({'success': False, 'message': 'End location not found'}), 404
            
        # Calculate distance
        distance = PostcodeService.calculate_distance(start_location.postcode, end_location.postcode)
        if distance is None:
            return jsonify({
                'success': False, 
                'message': 'Could not calculate distance between postcodes'
            }), 400
            
        # Create journey (both start and end times are set)
        now = datetime.utcnow()
        journey = Journey(
            start_postcode=start_location.postcode,
            end_postcode=end_location.postcode,
            start_time=now,
            end_time=now,
            distance_miles=distance,
            is_manual=True,
            start_location_id=start_location_id,
            end_location_id=end_location_id
        )
        db.session.add(journey)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Manual journey created successfully',
            'journey': journey.to_dict()
        })
        
    except Exception as e:
        logger.error(f"Error creating manual journey: {e}")
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Server error: {str(e)}'}), 500

@app.route('/api/auth/register', methods=['POST'])
def register():
    """API endpoint for user registration."""
    try:
        # Log detailed request information
        logger.info("=== Registration Request Details ===")
        logger.info(f"Request Method: {request.method}")
        logger.info(f"Request Headers: {dict(request.headers)}")
        logger.info(f"Request Content Type: {request.content_type}")
        logger.info(f"Request Data: {request.get_data()}")
        logger.info(f"Request JSON: {request.get_json(silent=True)}")
        logger.info(f"Request Form: {request.form}")
        logger.info(f"Request Args: {request.args}")
        logger.info("=================================")
        
        data = request.get_json()
        if not data:
            logger.error("No JSON data received in request")
            response = jsonify({
                'error': 'No data received'
            })
            response.headers.add('Access-Control-Allow-Origin', '*')
            return response, 400
            
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            logger.error(f"Missing required fields. Username: {bool(username)}, Password: {bool(password)}")
            response = jsonify({
                'error': 'Username and password are required'
            })
            response.headers.add('Access-Control-Allow-Origin', '*')
            return response, 400
            
        # Check if username already exists
        if User.query.filter_by(username=username).first():
            logger.error(f"Username already exists: {username}")
            response = jsonify({
                'error': 'Username already exists'
            })
            response.headers.add('Access-Control-Allow-Origin', '*')
            return response, 400
            
        # Create new user
        user = User(
            username=username,
            password_hash=generate_password_hash(password)
        )
        db.session.add(user)
        db.session.commit()
        
        # Generate token for immediate login
        token = jwt.encode(
            {
                'user_id': user.id,
                'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
            },
            app.config['SECRET_KEY'],
            algorithm='HS256'
        )
        
        logger.info(f"User registered successfully: {username}")
        response = jsonify({
            'message': 'User registered successfully'
        })
        response.headers.add('Access-Control-Allow-Origin', '*')
        return response, 201
        
    except Exception as e:
        logger.error(f"Error registering user: {str(e)}")
        db.session.rollback()
        response = jsonify({
            'error': 'Server error'
        })
        response.headers.add('Access-Control-Allow-Origin', '*')
        return response, 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """API endpoint for user login."""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password')
        
        if not username or not password:
            return jsonify({
                'success': False,
                'message': 'Username and password are required'
            }), 400
            
        # Find user
        user = User.query.filter_by(username=username).first()
        if not user or not check_password_hash(user.password_hash, password):
            return jsonify({
                'success': False,
                'message': 'Invalid username or password'
            }), 401
            
        # Generate JWT token
        token = jwt.encode(
            {
                'user_id': user.id,
                'exp': datetime.utcnow() + app.config['JWT_EXPIRATION_DELTA']
            },
            app.config['SECRET_KEY'],
            algorithm='HS256'
        )
        
        return jsonify({
            'success': True,
            'access_token': token
        })
        
    except Exception as e:
        logger.error(f"Error logging in: {e}")
        return jsonify({
            'success': False,
            'message': f'Server error: {str(e)}'
        }), 500
