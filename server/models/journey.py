from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from server.database import Base
from datetime import datetime

class Journey(Base):
    __tablename__ = 'journeys'

    id = Column(Integer, primary_key=True)
    start_postcode = Column(String, nullable=False)
    end_postcode = Column(String, nullable=True)
    distance = Column(Float, nullable=True)  # in kilometers
    start_time = Column(DateTime, nullable=False, default=datetime.utcnow)
    end_time = Column(DateTime, nullable=True)
    is_active = Column(Boolean, default=True)
    is_manual = Column(Boolean, default=False)
    
    # Foreign keys for locations
    start_location_id = Column(Integer, ForeignKey('postcodes.id'), nullable=True)
    end_location_id = Column(Integer, ForeignKey('postcodes.id'), nullable=True)
    
    # Relationships
    start_location = relationship("Postcode", foreign_keys=[start_location_id])
    end_location = relationship("Postcode", foreign_keys=[end_location_id])
    
    def __repr__(self):
        return f"<Journey(id={self.id}, start={self.start_postcode}, end={self.end_postcode})>" 