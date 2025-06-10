from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from server.models.journey import Journey
from server.models.postcode import Postcode
from server.database import get_db
import logging
from datetime import datetime

journeys_bp = Blueprint('journeys', __name__)

@journeys_bp.route('/', methods=['GET'])
@jwt_required()
def get_journeys():
    try:
        db = next(get_db())
        journeys = db.query(Journey).order_by(Journey.start_time.desc()).all()
        
        journey_list = []
        for journey in journeys:
            # Get start and end locations
            start_location = db.query(Postcode).filter_by(postcode=journey.start_postcode).first()
            end_location = db.query(Postcode).filter_by(postcode=journey.end_postcode).first() if journey.end_postcode else None
            
            journey_dict = {
                'id': journey.id,
                'start_postcode': journey.start_postcode,
                'end_postcode': journey.end_postcode or '',
                'distance_miles': journey.distance_miles or 0.0,
                'start_time': journey.start_time.isoformat() if journey.start_time else '',
                'end_time': journey.end_time.isoformat() if journey.end_time else '',
                'is_active': journey.end_time is None,
                'is_manual': journey.is_manual if hasattr(journey, 'is_manual') else False,
                'start_location': {
                    'id': start_location.id,
                    'name': start_location.name,
                    'postcode': start_location.postcode,
                    'latitude': start_location.latitude,
                    'longitude': start_location.longitude,
                    'created_at': start_location.created_at.isoformat() if start_location.created_at else None
                } if start_location else None,
                'end_location': {
                    'id': end_location.id,
                    'name': end_location.name,
                    'postcode': end_location.postcode,
                    'latitude': end_location.latitude,
                    'longitude': end_location.longitude,
                    'created_at': end_location.created_at.isoformat() if end_location.created_at else None
                } if end_location else None
            }
            journey_list.append(journey_dict)
        
        return jsonify(journey_list), 200
    except Exception as e:
        logging.error(f"Error fetching journeys: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@journeys_bp.route('/start', methods=['POST'])
@jwt_required()
def start_journey():
    try:
        data = request.get_json()
        if not data or 'start_postcode' not in data:
            return jsonify({'error': 'Start postcode is required'}), 400
        
        db = next(get_db())
        
        # Check if there's already an active journey
        active_journey = db.query(Journey).filter_by(end_time=None).first()
        if active_journey:
            return jsonify({
                'error': 'You already have an active journey in progress',
                'journey_id': active_journey.id
            }), 400
        
        # Create new journey
        journey = Journey(
            start_postcode=data['start_postcode'],
            start_time=datetime.utcnow(),
            is_manual=data.get('is_manual', False)
        )
        
        db.add(journey)
        db.commit()
        
        return jsonify({
            'journey_id': journey.id,
            'message': 'Journey started successfully'
        }), 201
    except Exception as e:
        logging.error(f"Error starting journey: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@journeys_bp.route('/<int:journey_id>/end', methods=['POST'])
@jwt_required()
def end_journey(journey_id):
    try:
        data = request.get_json()
        if not data or 'end_postcode' not in data:
            return jsonify({'error': 'End postcode is required'}), 400
        
        db = next(get_db())
        journey = db.query(Journey).filter_by(id=journey_id).first()
        
        if not journey:
            return jsonify({'error': 'Journey not found'}), 404
        
        if journey.end_time:
            return jsonify({'error': 'Journey is already completed'}), 400
        
        journey.end_postcode = data['end_postcode']
        journey.end_time = datetime.utcnow()
        journey.distance_miles = data.get('distance_miles', 0.0)
        
        db.commit()
        
        return jsonify({
            'message': 'Journey ended successfully',
            'journey': {
                'id': journey.id,
                'start_postcode': journey.start_postcode,
                'end_postcode': journey.end_postcode,
                'distance_miles': journey.distance_miles,
                'start_time': journey.start_time.isoformat(),
                'end_time': journey.end_time.isoformat(),
                'is_active': False,
                'is_manual': journey.is_manual if hasattr(journey, 'is_manual') else False
            }
        }), 200
    except Exception as e:
        logging.error(f"Error ending journey: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@journeys_bp.route('/<int:journey_id>', methods=['DELETE'])
@jwt_required()
def delete_journey(journey_id):
    try:
        db = next(get_db())
        journey = db.query(Journey).filter_by(id=journey_id).first()
        
        if not journey:
            return jsonify({'error': 'Journey not found'}), 404
        
        db.delete(journey)
        db.commit()
        
        return jsonify({'message': 'Journey deleted successfully'}), 200
    except Exception as e:
        logging.error(f"Error deleting journey: {str(e)}")
        return jsonify({'error': 'Server error'}), 500 