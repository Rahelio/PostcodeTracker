from flask import render_template, request, jsonify, flash, redirect, url_for
from datetime import datetime
import logging
from app import app, db
from models import Journey
from postcode_service import PostcodeService

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
