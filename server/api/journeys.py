from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from server.models.journey import Journey
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
                'distance': j.distance,
                'created_at': j.created_at.isoformat() if j.created_at else None
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
                'distance': journey.distance,
                'created_at': journey.created_at.isoformat() if journey.created_at else None
            }
        }), 200
    except Exception as e:
        logging.error(f"Error fetching journey: {str(e)}")
        return jsonify({
            'success': False,
            'error': 'Server error'
        }), 500 