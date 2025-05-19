from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from server.models.postcode import Postcode
from server.database import get_db
from server.utils.postcode_service import calculate_distance

postcodes_bp = Blueprint('postcodes', __name__)

@postcodes_bp.route('/', methods=['GET'])
@jwt_required()
def get_postcodes():
    current_user_id = get_jwt_identity()
    db = next(get_db())
    postcodes = db.query(Postcode).filter_by(user_id=current_user_id).all()
    return jsonify([{
        'id': p.id,
        'postcode': p.postcode,
        'created_at': p.created_at.isoformat(),
        'updated_at': p.updated_at.isoformat()
    } for p in postcodes]), 200

@postcodes_bp.route('/<int:postcode_id>', methods=['GET'])
@jwt_required()
def get_postcode(postcode_id):
    current_user_id = get_jwt_identity()
    db = next(get_db())
    postcode = db.query(Postcode).filter_by(id=postcode_id, user_id=current_user_id).first()
    if not postcode:
        return jsonify({'error': 'Postcode not found'}), 404
    return jsonify({
        'id': postcode.id,
        'postcode': postcode.postcode,
        'created_at': postcode.created_at.isoformat(),
        'updated_at': postcode.updated_at.isoformat()
    }), 200

@postcodes_bp.route('/', methods=['POST'])
@jwt_required()
def create_postcode():
    current_user_id = get_jwt_identity()
    data = request.get_json()
    
    if not data or not data.get('postcode'):
        return jsonify({'error': 'Postcode is required'}), 400
    
    db = next(get_db())
    postcode = Postcode(
        postcode=data['postcode'],
        user_id=current_user_id
    )
    
    db.add(postcode)
    db.commit()
    
    return jsonify({
        'id': postcode.id,
        'postcode': postcode.postcode,
        'created_at': postcode.created_at.isoformat(),
        'updated_at': postcode.updated_at.isoformat()
    }), 201

@postcodes_bp.route('/distance', methods=['POST'])
@jwt_required()
def calculate_postcode_distance():
    data = request.get_json()
    
    if not data or not all(k in data for k in ['postcode1', 'postcode2']):
        return jsonify({'error': 'Missing required fields'}), 400
    
    current_user_id = get_jwt_identity()
    db = next(get_db())
    postcode1 = db.query(Postcode).filter_by(postcode=data['postcode1'], user_id=current_user_id).first()
    postcode2 = db.query(Postcode).filter_by(postcode=data['postcode2'], user_id=current_user_id).first()
    
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

@postcodes_bp.route('/<int:postcode_id>', methods=['DELETE'])
@jwt_required()
def delete_postcode(postcode_id):
    current_user_id = get_jwt_identity()
    db = next(get_db())
    
    postcode = db.query(Postcode).filter_by(id=postcode_id, user_id=current_user_id).first()
    if not postcode:
        return jsonify({'error': 'Postcode not found'}), 404
    
    db.delete(postcode)
    db.commit()
    
    return jsonify({'message': 'Postcode deleted successfully'}), 200 