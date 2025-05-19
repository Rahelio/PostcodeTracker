from server.database import Base
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from datetime import datetime

class Postcode(Base):
    __tablename__ = 'postcodes'
    
    id = Column(Integer, primary_key=True)
    postcode = Column(String(10), nullable=False)
    user_id = Column(Integer, ForeignKey('users.id'), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'<Postcode {self.postcode}>' 