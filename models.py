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
    
    __tablename__ = 'journeys'
    
    id = db.Column(db.Integer, primary_key=True)
    start_postcode = db.Column(db.String(10), nullable=False)
    end_postcode = db.Column(db.String(10), nullable=True)
    start_time = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    end_time = db.Column(db.DateTime, nullable=True)
    distance_miles = db.Column(db.Float, nullable=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)
    
    def __repr__(self) -> str:
        return f'<Journey {self.id}: {self.start_postcode} to {self.end_postcode}>'
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert journey to a dictionary for JSON serialization."""
        return {
            'id': self.id,
            'start_postcode': self.start_postcode,
            'end_postcode': self.end_postcode,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'distance_miles': self.distance_miles,
            'is_active': self.end_time is None,
            'user_id': self.user_id
        }

class User(db.Model):
    """Model for user authentication and management."""
    
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    
    # Relationship to journeys
    journeys = db.relationship('Journey', backref='user', lazy=True)
    
    def __repr__(self) -> str:
        return f'<User {self.username}>'
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert user to a dictionary for JSON serialization."""
        return {
            'id': self.id,
            'username': self.username,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
