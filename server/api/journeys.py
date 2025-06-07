from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from server.models.journey import Journey
from server.models.postcode import Postcode
from server.database import get_db
import logging

journeys_bp = Blueprint('journeys', __name__)

@journeys_bp.route('/', methods=['GET'])
@jwt_required()
def get_journeys():
    try:
        db = next(get_db())
        journeys = db.query(Journey).all()
        return jsonify({
            'success': True,
            'journeys': [{
                'id': j.id,
                'start_postcode': j.start_postcode,
                'end_postcode': j.end_postcode,
                'distance_miles': j.distance if j.distance else 0.0,  # Convert km to miles if needed
                'start_time': j.start_time.isoformat() if j.start_time else None,
                'end_time': j.end_time.isoformat() if j.end_time else None,
                'is_active': j.is_active if hasattr(j, 'is_active') else False,
                'is_manual': j.is_manual if hasattr(j, 'is_manual') else False,
                'start_location': {
                    'id': j.start_location.id,
                    'name': j.start_location.name,
                    'postcode': j.start_location.postcode,
                    'latitude': j.start_location.latitude,
                    'longitude': j.start_location.longitude,
                    'created_at': j.start_location.created_at.isoformat() if j.start_location.created_at else None
                } if j.start_location else None,
                'end_location': {
                    'id': j.end_location.id,
                    'name': j.end_location.name,
                    'postcode': j.end_location.postcode,
                    'latitude': j.end_location.latitude,
                    'longitude': j.end_location.longitude,
                    'created_at': j.end_location.created_at.isoformat() if j.end_location.created_at else None
                } if j.end_location else None
            } for j in journeys]
        }), 200
    except Exception as e:
        logging.error(f"Error fetching journeys: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Server error'
        }), 500

@journeys_bp.route('/<int:journey_id>', methods=['GET'])
@jwt_required()
def get_journey(journey_id):
    try:
        db = next(get_db())
        journey = db.query(Journey).filter_by(id=journey_id).first()
        if not journey:
            return jsonify({
                'success': False,
                'error': 'Journey not found'
            }), 404
        return jsonify({
            'success': True,
            'journey': {
                'id': journey.id,
                'start_postcode': journey.start_postcode,
                'end_postcode': journey.end_postcode,
                'distance_miles': journey.distance if journey.distance else 0.0,  # Convert km to miles if needed
                'start_time': journey.start_time.isoformat() if journey.start_time else None,
                'end_time': journey.end_time.isoformat() if journey.end_time else None,
                'is_active': journey.is_active if hasattr(journey, 'is_active') else False,
                'is_manual': journey.is_manual if hasattr(journey, 'is_manual') else False,
                'start_location': {
                    'id': journey.start_location.id,
                    'name': journey.start_location.name,
                    'postcode': journey.start_location.postcode,
                    'latitude': journey.start_location.latitude,
                    'longitude': journey.start_location.longitude,
                    'created_at': journey.start_location.created_at.isoformat() if journey.start_location.created_at else None
                } if journey.start_location else None,
                'end_location': {
                    'id': journey.end_location.id,
                    'name': journey.end_location.name,
                    'postcode': journey.end_location.postcode,
                    'latitude': journey.end_location.latitude,
                    'longitude': journey.end_location.longitude,
                    'created_at': journey.end_location.created_at.isoformat() if journey.end_location.created_at else None
                } if journey.end_location else None
            }
        }), 200
    except Exception as e:
        logging.error(f"Error fetching journey: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Server error'
        }), 500 