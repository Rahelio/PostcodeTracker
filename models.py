from datetime import datetime
from app import db
from typing import Dict, Any, Optional

class Journey(db.Model):
    """Model for storing journey information between UK postcodes."""
    id = db.Column(db.Integer, primary_key=True)
    start_postcode = db.Column(db.String(10), nullable=False)
    end_postcode = db.Column(db.String(10), nullable=True)
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime, nullable=True)
    distance_miles = db.Column(db.Float, nullable=True)
    
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
            'is_active': self.end_time is None
        }
