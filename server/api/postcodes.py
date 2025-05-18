from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from models.postcode import Postcode
from app import db
from utils.postcode_service import calculate_distance

postcodes_bp = Blueprint('postcodes', __name__)

@postcodes_bp.route('/', methods=['GET'])
@jwt_required()
def get_postcodes():
    postcodes = Postcode.query.all()
    return jsonify([{
        'id': p.id,
        'code': p.code,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'created_at': p.created_at.isoformat(),
        'updated_at': p.updated_at.isoformat()
    } for p in postcodes]), 200

@postcodes_bp.route('/<int:postcode_id>', methods=['GET'])
@jwt_required()
def get_postcode(postcode_id):
    postcode = Postcode.query.get_or_404(postcode_id)
    return jsonify({
        'id': postcode.id,
        'code': postcode.code,
        'latitude': postcode.latitude,
        'longitude': postcode.longitude,
        'created_at': postcode.created_at.isoformat(),
        'updated_at': postcode.updated_at.isoformat()
    }), 200

@postcodes_bp.route('/', methods=['POST'])
@jwt_required()
def create_postcode():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['code', 'latitude', 'longitude']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    postcode = Postcode(
        code=data['code'],
        latitude=data['latitude'],
        longitude=data['longitude']
    )
    
    db.session.add(postcode)
    db.session.commit()
    
    return jsonify({
        'id': postcode.id,
        'code': postcode.code,
        'latitude': postcode.latitude,
        'longitude': postcode.longitude,
        'created_at': postcode.created_at.isoformat(),
        'updated_at': postcode.updated_at.isoformat()
    }), 201

@postcodes_bp.route('/distance', methods=['POST'])
@jwt_required()
def calculate_postcode_distance():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['postcode1', 'postcode2']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    postcode1 = Postcode.query.filter_by(code=data['postcode1']).first()
    postcode2 = Postcode.query.filter_by(code=data['postcode2']).first()
    
    if not postcode1 or not postcode2:
        return jsonify({'error': 'One or both postcodes not found'}), 404
    
    distance = calculate_distance(
        (postcode1.latitude, postcode1.longitude),
        (postcode2.latitude, postcode2.longitude)
    )
    
    return jsonify({
        'distance': distance,
        'unit': 'kilometers'
    }), 200 