from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Use the DATABASE_URL from environment variable
DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://locator:Aberdeen24@0.0.0.0:5432/postcodetrackerdb')

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def init_db():
    try:
        # Create tables if they don't exist
        Base.metadata.create_all(bind=engine)
    except Exception as e:
        print(f"Error initializing database: {e}")
        raise

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close() 