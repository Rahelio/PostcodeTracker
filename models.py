from datetime import datetime
from app import db
from typing import Dict, Any, Optional

class Postcode(db.Model):
    """Model for storing saved locations with names and UK postcodes."""
    __tablename__ = 'saved_location'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    postcode = db.Column(db.String(10), nullable=False)
    latitude = db.Column(db.Float)
    longitude = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __init__(self, **kwargs):
        """Initialize a Postcode instance with keyword arguments."""
        super(Postcode, self).__init__(**kwargs)
        
    def __repr__(self) -> str:
        """String representation of a Postcode instance."""
        return f"<Postcode {self.id}: {self.name} ({self.postcode})>"
        
    def to_dict(self) -> Dict[str, Any]:
        """Convert postcode to a dictionary for JSON serialization."""
        return {
            'id': self.id,
            'name': self.name,
            'postcode': self.postcode,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M:%S') if self.created_at else None
        }

class Journey(db.Model):
    """Model for storing journey information between UK postcodes."""
    id = db.Column(db.Integer, primary_key=True)
    start_postcode = db.Column(db.String(10), nullable=False)
    end_postcode = db.Column(db.String(10), nullable=True)
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime, nullable=True)
    distance_miles = db.Column(db.Float, nullable=True)
    is_manual = db.Column(db.Boolean, default=False)
    
    # Optional references to saved locations
    start_location_id = db.Column(db.Integer, db.ForeignKey('saved_location.id'), nullable=True)
    end_location_id = db.Column(db.Integer, db.ForeignKey('saved_location.id'), nullable=True)
    
    # Relationships
    start_location = db.relationship('Postcode', foreign_keys=[start_location_id])
    end_location = db.relationship('Postcode', foreign_keys=[end_location_id])
    
    def __init__(self, **kwargs):
        """Initialize a Journey instance with keyword arguments."""
        super(Journey, self).__init__(**kwargs)
    
    def __repr__(self) -> str:
        return f'<Journey {self.start_postcode} to {self.end_postcode}>'
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert journey to a dictionary for JSON serialization."""
        return {
            'id': self.id,
            'start_postcode': self.start_postcode,
            'end_postcode': self.end_postcode,
            'start_time': self.start_time.strftime('%Y-%m-%d %H:%M:%S') if self.start_time else None,
            'end_time': self.end_time.strftime('%Y-%m-%d %H:%M:%S') if self.end_time else None,
            'distance_miles': self.distance_miles,
            'is_active': self.end_time is None,
            'is_manual': self.is_manual,
            'start_location': self.start_location.to_dict() if self.start_location else None,
            'end_location': self.end_location.to_dict() if self.end_location else None
        }

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(256))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<User {self.username}>'
