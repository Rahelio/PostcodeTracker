from flask import render_template, request, jsonify, flash, redirect, url_for, send_file
from datetime import datetime
import logging
import json
import io
import pandas as pd
import tempfile
import csv
from app import app, db
from models import Journey
from postcode_service import PostcodeService
from export_util import export_to_csv, export_to_excel, get_journey_data

logger = logging.getLogger(__name__)

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
            import tempfile
            journey_data = get_journey_data(journey_ids)
            
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
            import tempfile
            from export_util import get_journey_data
            
            journey_data = get_journey_data(journey_ids)
            
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
