import requests
import logging
import math
from typing import Tuple, Optional, Dict, Any
from datetime import datetime
from models import PostcodeCache
from app import db

logger = logging.getLogger(__name__)

class PostcodeService:
    """Service for UK postcode validation and distance calculation with caching."""
    
    BASE_URL = "https://api.postcodes.io"
    
    @staticmethod
    def get_postcode_from_coordinates(latitude: float, longitude: float) -> Optional[str]:
        """
        Reverse geocodes coordinates to find the nearest UK postcode.
        
        Args:
            latitude: The latitude coordinate
            longitude: The longitude coordinate
            
        Returns:
            Optional[str]: The nearest postcode or None if not found
        """
        try:
            url = f"{PostcodeService.BASE_URL}/postcodes?lon={longitude}&lat={latitude}"
            logger.debug(f"Making reverse geocode request to: {url}")
            
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 200 and data.get('result') and len(data['result']) > 0:
                    postcode_data = data['result'][0]
                    postcode = postcode_data['postcode']
                    
                    # Cache the postcode data for future use
                    PostcodeService._cache_postcode_data(
                        postcode,
                        postcode_data['latitude'],
                        postcode_data['longitude']
                    )
                    
                    return postcode
            
            logger.warning(f"Failed to find postcode for coordinates ({latitude}, {longitude})")
            return None
        except Exception as e:
            logger.error(f"Error in reverse geocoding: {e}")
            return None
    
    @staticmethod
    def get_postcode_coordinates(postcode: str) -> Optional[Dict[str, float]]:
        """
        Gets coordinates for a postcode, using cache first, then API if needed.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[Dict]: Dictionary with latitude and longitude or None if not found
        """
        # Normalize postcode
        normalized_postcode = postcode.upper().replace(" ", "")
        
        # Check cache first
        cached_data = PostcodeCache.query.filter_by(postcode=normalized_postcode).first()
        if cached_data:
            logger.debug(f"Found cached coordinates for {postcode}")
            cached_data.update_access_time()
            db.session.commit()
            return {
                'latitude': cached_data.latitude,
                'longitude': cached_data.longitude
            }
        
        # Not in cache, fetch from API
        logger.debug(f"Fetching coordinates for {postcode} from API")
        try:
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{normalized_postcode}", timeout=10)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 200 and data.get('result'):
                    result = data['result']
                    coordinates = {
                        'latitude': result['latitude'],
                        'longitude': result['longitude']
                    }
                    
                    # Cache the result
                    PostcodeService._cache_postcode_data(
                        normalized_postcode,
                        result['latitude'],
                        result['longitude']
                    )
                    
                    return coordinates
            return None
        except Exception as e:
            logger.error(f"Error getting coordinates for postcode {postcode}: {e}")
            return None
    
    @staticmethod
    def _cache_postcode_data(postcode: str, latitude: float, longitude: float):
        """
        Cache postcode data in the database.
        
        Args:
            postcode: The postcode to cache
            latitude: The latitude coordinate
            longitude: The longitude coordinate
        """
        try:
            # Normalize postcode
            normalized_postcode = postcode.upper().replace(" ", "")
            
            # Check if already exists
            existing = PostcodeCache.query.filter_by(postcode=normalized_postcode).first()
            if existing:
                existing.update_access_time()
            else:
                # Create new cache entry
                cache_entry = PostcodeCache(
                    postcode=normalized_postcode,
                    latitude=latitude,
                    longitude=longitude
                )
                db.session.add(cache_entry)
            
            db.session.commit()
            logger.debug(f"Cached coordinates for postcode {postcode}")
        except Exception as e:
            logger.error(f"Error caching postcode data: {e}")
            db.session.rollback()
    
    @staticmethod
    def validate_postcode(postcode: str) -> bool:
        """
        Validates a UK postcode format.
        
        Args:
            postcode: The postcode to validate
            
        Returns:
            bool: True if the postcode is valid, False otherwise
        """
        try:
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{postcode}/validate", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('result', False)
            return False
        except Exception as e:
            logger.error(f"Error validating postcode: {e}")
            return False
    
    @staticmethod
    def get_postcode_data(postcode: str) -> Optional[Dict[str, Any]]:
        """
        Gets location data for a postcode (legacy method - use get_postcode_coordinates for better caching).
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[Dict]: Dictionary containing postcode data or None if not found
        """
        try:
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{postcode}", timeout=10)
            if response.status_code == 200:
                data = response.json()
                return data.get('result')
            return None
        except Exception as e:
            logger.error(f"Error getting postcode data: {e}")
            return None
    
    @staticmethod
    def calculate_distance_from_coordinates(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance between two coordinate pairs using cached data.
        
        Args:
            lat1, lon1: Start coordinates
            lat2, lon2: End coordinates
            
        Returns:
            float: Distance in miles
        """
        # Calculate distance using Haversine formula
        distance_km = PostcodeService._haversine(lat1, lon1, lat2, lon2)
        
        # Convert to miles (1 km = 0.621371 miles)
        distance_miles = distance_km * 0.621371
        
        # Round to 2 decimal places
        return round(distance_miles, 2)
    
    @staticmethod
    def calculate_distance(start_postcode: str, end_postcode: str) -> Optional[float]:
        """
        Calculates the distance in miles between two UK postcodes using cached coordinates.
        
        Args:
            start_postcode: The starting postcode
            end_postcode: The ending postcode
            
        Returns:
            Optional[float]: Distance in miles or None if calculation fails
        """
        try:
            start_coords = PostcodeService.get_postcode_coordinates(start_postcode)
            end_coords = PostcodeService.get_postcode_coordinates(end_postcode)
            
            if not start_coords or not end_coords:
                return None
            
            return PostcodeService.calculate_distance_from_coordinates(
                start_coords['latitude'], start_coords['longitude'],
                end_coords['latitude'], end_coords['longitude']
            )
            
        except Exception as e:
            logger.error(f"Error calculating distance: {e}")
            return None
    
    @staticmethod
    def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate the great circle distance between two points 
        on the earth (specified in decimal degrees).
        
        Args:
            lat1, lon1: Coordinates of first point
            lat2, lon2: Coordinates of second point
            
        Returns:
            float: Distance in kilometers
        """
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlon = lon2 - lon1
        dlat = lat2 - lat1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        r = 6371  # Radius of earth in kilometers
        return c * r

    @staticmethod
    def get_postcode_details(postcode: str) -> Optional[Dict[str, Any]]:
        """
        Gets location data for a postcode using cached coordinates.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[Dict]: Dictionary containing postcode data or None if not found
        """
        coords = PostcodeService.get_postcode_coordinates(postcode)
        if coords:
            return {
                'latitude': coords['latitude'],
                'longitude': coords['longitude']
            }
        return None
