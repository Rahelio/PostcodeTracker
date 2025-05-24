from server.database import Base
from sqlalchemy import Column, Integer, String, DateTime, Float
from datetime import datetime

class Postcode(Base):
    __tablename__ = 'saved_location'
    
    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    postcode = Column(String(10), nullable=False)
    latitude = Column(Float)
    longitude = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    def __repr__(self):
        return f'<Postcode {self.postcode}>' 