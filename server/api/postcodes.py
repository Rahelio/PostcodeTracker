from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from server.models.postcode import Postcode
from server.database import get_db
from server.utils.postcode_service import calculate_distance
import requests
import logging

postcodes_bp = Blueprint('postcodes', __name__)

@postcodes_bp.route('/', methods=['GET'])
@jwt_required()
def get_postcodes():
    try:
        db = next(get_db())
        postcodes = db.query(Postcode).all()
        return jsonify([{
            'id': p.id,
            'name': p.name,
            'postcode': p.postcode,
            'created_at': p.created_at.isoformat() if p.created_at else None
        } for p in postcodes]), 200
    except Exception as e:
        logging.error(f"Error fetching postcodes: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@postcodes_bp.route('/<int:postcode_id>', methods=['GET'])
@jwt_required()
def get_postcode(postcode_id):
    try:
        db = next(get_db())
        postcode = db.query(Postcode).filter_by(id=postcode_id).first()
        if not postcode:
            return jsonify({'error': 'Postcode not found'}), 404
        return jsonify({
            'id': postcode.id,
            'name': postcode.name,
            'postcode': postcode.postcode,
            'created_at': postcode.created_at.isoformat() if postcode.created_at else None
        }), 200
    except Exception as e:
        logging.error(f"Error fetching postcode: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@postcodes_bp.route('/', methods=['POST'])
@jwt_required()
def create_postcode():
    try:
        data = request.get_json()
        
        if not data or not data.get('postcode'):
            return jsonify({'error': 'Postcode is required'}), 400
        
        # Validate postcode
        response = requests.get(f"https://api.postcodes.io/postcodes/{data['postcode']}/validate")
        if not response.json().get('result'):
            return jsonify({'error': 'Invalid postcode'}), 400
        
        # Get postcode details
        response = requests.get(f"https://api.postcodes.io/postcodes/{data['postcode']}")
        if response.status_code != 200:
            return jsonify({'error': 'Could not validate postcode'}), 400
        
        postcode_data = response.json()['result']
        
        if not data.get('name'):
            data['name'] = data['postcode']  # Use postcode as name if not provided
        
        db = next(get_db())
        postcode = Postcode(
            postcode=data['postcode'],
            name=data['name'],
            latitude=postcode_data['latitude'],
            longitude=postcode_data['longitude']
        )
        
        db.add(postcode)
        db.commit()
        
        return jsonify({
            'id': postcode.id,
            'name': postcode.name,
            'postcode': postcode.postcode,
            'created_at': postcode.created_at.isoformat() if postcode.created_at else None
        }), 201
    except Exception as e:
        logging.error(f"Error adding postcode: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@postcodes_bp.route('/distance', methods=['POST'])
@jwt_required()
def calculate_postcode_distance():
    try:
        data = request.get_json()
        
        if not data or not all(k in data for k in ['postcode1', 'postcode2']):
            return jsonify({'error': 'Missing required fields'}), 400
        
        db = next(get_db())
        postcode1 = db.query(Postcode).filter_by(postcode=data['postcode1']).first()
        postcode2 = db.query(Postcode).filter_by(postcode=data['postcode2']).first()
        
        if not postcode1 or not postcode2:
            return jsonify({'error': 'One or both postcodes not found'}), 404
        
        if not postcode1.latitude or not postcode1.longitude or not postcode2.latitude or not postcode2.longitude:
            return jsonify({'error': 'Missing coordinates for one or both postcodes'}), 400
        
        distance = calculate_distance(
            (postcode1.latitude, postcode1.longitude),
            (postcode2.latitude, postcode2.longitude)
        )
        
        return jsonify({
            'distance': distance,
            'unit': 'kilometers'
        }), 200
    except Exception as e:
        logging.error(f"Error calculating distance: {str(e)}")
        return jsonify({'error': 'Server error'}), 500

@postcodes_bp.route('/<int:postcode_id>', methods=['DELETE'])
@jwt_required()
def delete_postcode(postcode_id):
    try:
        db = next(get_db())
        
        postcode = db.query(Postcode).filter_by(id=postcode_id).first()
        if not postcode:
            return jsonify({'error': 'Postcode not found'}), 404
        
        db.delete(postcode)
        db.commit()
        
        return jsonify({'message': 'Postcode deleted successfully'}), 200
    except Exception as e:
        logging.error(f"Error deleting postcode: {str(e)}")
        return jsonify({'error': 'Server error'}), 500 