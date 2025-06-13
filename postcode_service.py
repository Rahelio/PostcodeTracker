import requests
import logging
import math
import time
from typing import Tuple, Optional, Dict, Any
from dataclasses import dataclass

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
    """Robust service for UK postcode validation and distance calculation."""
    
    BASE_URL = "https://api.postcodes.io"
    BACKUP_URL = "https://postcodes.io/api"  # Fallback URL
    MAX_RETRIES = 2  # Reduced from 3 to 2
    RETRY_DELAY = 0.5  # Reduced from 1 to 0.5 seconds
    REQUEST_TIMEOUT = 8  # Reduced from 10 to 8 seconds
    
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
                time.sleep(cls.RETRY_DELAY)  # Fixed delay instead of exponential for speed
                
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
            
            # Try primary URL with reduced retries for speed
            logger.info(f"Looking up postcode for coordinates ({latitude}, {longitude})")
            url = f"{cls.BASE_URL}/postcodes?lon={longitude}&lat={latitude}"
            data = cls._make_request(url, max_retries=1)  # Only 1 retry for speed
            
            if data and data.get('result') and len(data['result']) > 0:
                postcode = data['result'][0].get('postcode')
                if postcode:
                    logger.info(f"Found postcode {postcode} for coordinates ({latitude}, {longitude})")
                    return postcode.strip().replace(' ', '')  # Normalize format
            
            # Try backup URL if primary fails - also with reduced retries
            logger.info(f"Primary API failed, trying backup for coordinates ({latitude}, {longitude})")
            backup_url = f"{cls.BACKUP_URL}/postcodes?lon={longitude}&lat={latitude}"
            backup_data = cls._make_request(backup_url, max_retries=1)  # Only 1 retry for speed
            
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
    
    @classmethod
    def validate_postcode(cls, postcode: str) -> bool:
        """
        Validate UK postcode format.
        
        Args:
            postcode: The postcode to validate
            
        Returns:
            bool: True if valid UK postcode format
        """
        if not postcode or not isinstance(postcode, str):
            return False
        
        # Remove spaces and convert to uppercase
        clean_postcode = postcode.strip().upper().replace(' ', '')
        
        # Basic UK postcode pattern validation
        import re
        uk_postcode_pattern = r'^[A-Z]{1,2}\d[A-Z\d]?\d[A-Z]{2}$'
        
        if not re.match(uk_postcode_pattern, clean_postcode):
            return False
            
        return True
    
    @classmethod
    def get_postcode_info(cls, postcode: str) -> Optional[PostcodeInfo]:
        """
        Get detailed information for a postcode.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[PostcodeInfo]: Postcode information or None if not found
        """
        if not cls.validate_postcode(postcode):
            logger.warning(f"Invalid postcode format: {postcode}")
            return None
        
        normalized_postcode = postcode.strip().upper().replace(' ', '')
        
        # Try primary URL
        url = f"{cls.BASE_URL}/postcodes/{normalized_postcode}"
        data = cls._make_request(url)
        
        if data and data.get('result'):
            result = data['result']
            return PostcodeInfo(
                postcode=result['postcode'],
                latitude=result['latitude'],
                longitude=result['longitude'],
                region=result.get('region'),
                district=result.get('admin_district')
            )
        
        # Try backup URL
        backup_url = f"{cls.BACKUP_URL}/postcodes/{normalized_postcode}"
        backup_data = cls._make_request(backup_url)
        
        if backup_data and backup_data.get('result'):
            result = backup_data['result']
            return PostcodeInfo(
                postcode=result['postcode'],
                latitude=result['latitude'],
                longitude=result['longitude'],
                region=result.get('region'),
                district=result.get('admin_district')
            )
        
        logger.warning(f"Postcode not found: {postcode}")
        return None
    
    @classmethod
    def calculate_distance(cls, postcode1: str, postcode2: str) -> Optional[float]:
        """
        Calculate distance in miles between two UK postcodes.
        
        Args:
            postcode1: First postcode
            postcode2: Second postcode
            
        Returns:
            Optional[float]: Distance in miles or None if calculation fails
        """
        try:
            info1 = cls.get_postcode_info(postcode1)
            info2 = cls.get_postcode_info(postcode2)
            
            if not info1 or not info2:
                logger.warning(f"Could not get coordinates for postcodes: {postcode1}, {postcode2}")
                return None
            
            distance = cls.calculate_distance_from_coordinates(
                info1.latitude, info1.longitude,
                info2.latitude, info2.longitude
            )
            
            logger.info(f"Distance between {postcode1} and {postcode2}: {distance:.2f} miles")
            return distance
            
        except Exception as e:
            logger.error(f"Error calculating distance between {postcode1} and {postcode2}: {e}")
            return None
    
    @staticmethod
    def calculate_distance_from_coordinates(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculate distance in miles between two coordinate points using Haversine formula.
        
        Args:
            lat1, lon1: First coordinate point
            lat2, lon2: Second coordinate point
            
        Returns:
            float: Distance in miles
        """
        # Earth's radius in miles
        R = 3959.0
        
        # Convert coordinates to radians
        lat1_rad = math.radians(lat1)
        lon1_rad = math.radians(lon1)
        lat2_rad = math.radians(lat2)
        lon2_rad = math.radians(lon2)
        
        # Calculate differences
        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad
        
        # Haversine formula
        a = (math.sin(dlat / 2) ** 2 + 
             math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        distance = R * c
        return round(distance, 2)
    
    @classmethod
    def bulk_validate_postcodes(cls, postcodes: list) -> Dict[str, bool]:
        """
        Validate multiple postcodes at once.
        
        Args:
            postcodes: List of postcodes to validate
            
        Returns:
            Dict[str, bool]: Dictionary mapping postcodes to validation results
        """
        results = {}
        
        for postcode in postcodes:
            results[postcode] = cls.validate_postcode(postcode)
        
        return results
    
    @classmethod
    def get_postcode_coordinates(cls, postcode: str) -> Optional[Dict[str, float]]:
        """
        Get coordinates for a postcode.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[Dict]: Dictionary with latitude and longitude or None if not found
        """
        info = cls.get_postcode_info(postcode)
        if info:
            return {
                'latitude': info.latitude,
                'longitude': info.longitude
            }
        return None
