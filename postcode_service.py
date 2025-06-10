import requests
import logging
import math
import time
from typing import Tuple, Optional, Dict, Any
<<<<<<< HEAD
from dataclasses import dataclass
=======
from datetime import datetime
from models import PostcodeCache
from app import db
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2

logger = logging.getLogger(__name__)

@dataclass
class PostcodeInfo:
    """Data class for postcode information."""
    postcode: str
    latitude: float
    longitude: float
    region: Optional[str] = None
    district: Optional[str] = None

class PostcodeService:
<<<<<<< HEAD
    """Robust service for UK postcode validation and distance calculation."""
=======
    """Service for UK postcode validation and distance calculation with caching."""
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
    
    BASE_URL = "https://api.postcodes.io"
    BACKUP_URL = "https://postcodes.io/api"  # Fallback URL
    MAX_RETRIES = 3
    RETRY_DELAY = 1  # seconds
    REQUEST_TIMEOUT = 10  # seconds
    
    @classmethod
    def _make_request(cls, url: str, max_retries: int = None) -> Optional[Dict[str, Any]]:
        """Make a robust HTTP request with retries."""
        if max_retries is None:
            max_retries = cls.MAX_RETRIES
            
        for attempt in range(max_retries + 1):
            try:
                logger.debug(f"Making request to {url} (attempt {attempt + 1})")
                response = requests.get(url, timeout=cls.REQUEST_TIMEOUT)
                
                if response.status_code == 200:
                    data = response.json()
                    if data.get('status') == 200:
                        return data
                    else:
                        logger.warning(f"API returned non-200 status: {data.get('status')}")
                        
                elif response.status_code == 404:
                    logger.info(f"Resource not found (404): {url}")
                    return None
                    
                else:
                    logger.warning(f"HTTP {response.status_code} from {url}")
                    
            except requests.exceptions.Timeout:
                logger.warning(f"Request timeout for {url} (attempt {attempt + 1})")
            except requests.exceptions.ConnectionError:
                logger.warning(f"Connection error for {url} (attempt {attempt + 1})")
            except requests.exceptions.RequestException as e:
                logger.warning(f"Request exception for {url}: {e} (attempt {attempt + 1})")
            except Exception as e:
                logger.error(f"Unexpected error for {url}: {e} (attempt {attempt + 1})")
            
            if attempt < max_retries:
                time.sleep(cls.RETRY_DELAY * (attempt + 1))  # Exponential backoff
                
        logger.error(f"All {max_retries + 1} attempts failed for {url}")
        return None
    
    @classmethod
    def get_postcode_from_coordinates(cls, latitude: float, longitude: float) -> Optional[str]:
        """
        Reverse geocode coordinates to find the nearest UK postcode.
        
        Args:
            latitude: The latitude coordinate
            longitude: The longitude coordinate
            
        Returns:
            Optional[str]: The nearest postcode or None if not found
        """
        try:
            # Validate coordinates
            if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
                logger.error(f"Invalid coordinates: lat={latitude}, lon={longitude}")
                return None
            
<<<<<<< HEAD
            # Try primary URL
            url = f"{cls.BASE_URL}/postcodes?lon={longitude}&lat={latitude}"
            data = cls._make_request(url)
=======
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
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
            
            if data and data.get('result') and len(data['result']) > 0:
                postcode = data['result'][0].get('postcode')
                if postcode:
                    logger.info(f"Found postcode {postcode} for coordinates ({latitude}, {longitude})")
                    return postcode.strip().replace(' ', '')  # Normalize format
            
            # Try backup URL if primary fails
            backup_url = f"{cls.BACKUP_URL}/postcodes?lon={longitude}&lat={latitude}"
            backup_data = cls._make_request(backup_url)
            
            if backup_data and backup_data.get('result') and len(backup_data['result']) > 0:
                postcode = backup_data['result'][0].get('postcode')
                if postcode:
                    logger.info(f"Found postcode {postcode} via backup API for coordinates ({latitude}, {longitude})")
                    return postcode.strip().replace(' ', '')
            
            logger.warning(f"No postcode found for coordinates ({latitude}, {longitude})")
            return None
            
        except Exception as e:
            logger.error(f"Error in reverse geocoding: {e}")
            return None
    
<<<<<<< HEAD
    @classmethod
    def validate_postcode(cls, postcode: str) -> bool:
=======
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
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
        """
        Validate a UK postcode format and existence.
        
        Args:
            postcode: The postcode to validate
            
        Returns:
            bool: True if the postcode is valid, False otherwise
        """
        try:
<<<<<<< HEAD
            if not postcode or not isinstance(postcode, str):
                return False
                
            # Clean the postcode
            clean_postcode = postcode.strip().upper().replace(' ', '')
            
            if len(clean_postcode) < 5 or len(clean_postcode) > 7:
                return False
            
            # Try validation endpoint
            url = f"{cls.BASE_URL}/postcodes/{clean_postcode}/validate"
            data = cls._make_request(url)
            
            if data and 'result' in data:
                return bool(data['result'])
            
            # Fallback: try to get postcode data
            postcode_data = cls.get_postcode_info(clean_postcode)
            return postcode_data is not None
            
=======
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{postcode}/validate", timeout=5)
            if response.status_code == 200:
                data = response.json()
                return data.get('result', False)
            return False
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
        except Exception as e:
            logger.error(f"Error validating postcode {postcode}: {e}")
            return False
    
    @classmethod
    def get_postcode_info(cls, postcode: str) -> Optional[PostcodeInfo]:
        """
        Get comprehensive information for a postcode.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[PostcodeInfo]: PostcodeInfo object or None if not found
        """
        try:
            if not postcode:
                return None
                
            clean_postcode = postcode.strip().upper().replace(' ', '')
            
            # Try primary URL
            url = f"{cls.BASE_URL}/postcodes/{clean_postcode}"
            data = cls._make_request(url)
            
            if data and data.get('result'):
                result = data['result']
                return PostcodeInfo(
                    postcode=result.get('postcode', clean_postcode),
                    latitude=float(result.get('latitude', 0)),
                    longitude=float(result.get('longitude', 0)),
                    region=result.get('region'),
                    district=result.get('admin_district')
                )
            
            # Try backup URL
            backup_url = f"{cls.BACKUP_URL}/postcodes/{clean_postcode}"
            backup_data = cls._make_request(backup_url)
            
            if backup_data and backup_data.get('result'):
                result = backup_data['result']
                return PostcodeInfo(
                    postcode=result.get('postcode', clean_postcode),
                    latitude=float(result.get('latitude', 0)),
                    longitude=float(result.get('longitude', 0)),
                    region=result.get('region'),
                    district=result.get('admin_district')
                )
                
            return None
            
        except Exception as e:
            logger.error(f"Error getting postcode info for {postcode}: {e}")
            return None
    
    @classmethod
    def calculate_distance(cls, start_postcode: str, end_postcode: str) -> Optional[float]:
        """
        Calculate the distance in miles between two UK postcodes.
        
        Args:
            start_postcode: The starting postcode
            end_postcode: The ending postcode
            
        Returns:
            Optional[float]: Distance in miles or None if calculation fails
        """
        try:
            # Get postcode information
            start_info = cls.get_postcode_info(start_postcode)
            end_info = cls.get_postcode_info(end_postcode)
            
            if not start_info or not end_info:
                logger.error(f"Could not get info for postcodes: {start_postcode}, {end_postcode}")
                return None
            
            # Validate coordinates
            if (start_info.latitude == 0 and start_info.longitude == 0) or \
               (end_info.latitude == 0 and end_info.longitude == 0):
                logger.error(f"Invalid coordinates for postcodes: {start_postcode}, {end_postcode}")
                return None
            
            # Calculate distance using Haversine formula
            distance_km = cls._haversine(
                start_info.latitude, start_info.longitude,
                end_info.latitude, end_info.longitude
            )
            
            # Convert to miles (1 km = 0.621371 miles)
            distance_miles = distance_km * 0.621371
            
            # Round to 2 decimal places
            result = round(distance_miles, 2)
            logger.info(f"Distance between {start_postcode} and {end_postcode}: {result} miles")
            
            return result
            
        except Exception as e:
            logger.error(f"Error calculating distance between {start_postcode} and {end_postcode}: {e}")
            return None
    
    @staticmethod
    def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate the great circle distance between two points using the Haversine formula.
        
        Args:
            lat1, lon1: Coordinates of first point
            lat2, lon2: Coordinates of second point
            
        Returns:
            float: Distance in kilometers
        """
        # Convert decimal degrees to radians
        lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
        
        # Haversine formula
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
        c = 2 * math.asin(math.sqrt(a))
        
        # Radius of earth in kilometers
        radius_km = 6371
        
        return c * radius_km

    @staticmethod
    def get_postcode_details(postcode: str) -> Optional[Dict[str, Any]]:
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
<<<<<<< HEAD
=======
    
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
>>>>>>> d0761ee184fabf1bb39d37c6c7d01a5ed69b52c2
