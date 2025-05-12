import requests
import logging
import math
from typing import Tuple, Optional, Dict, Any

logger = logging.getLogger(__name__)

class PostcodeService:
    """Service for UK postcode validation and distance calculation."""
    
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
            
            response = requests.get(url)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 200 and data.get('result') and len(data['result']) > 0:
                    return data['result'][0]['postcode']
            
            logger.warning(f"Failed to find postcode for coordinates ({latitude}, {longitude})")
            return None
        except Exception as e:
            logger.error(f"Error in reverse geocoding: {e}")
            return None
    
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
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{postcode}/validate")
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
        Gets location data for a postcode.
        
        Args:
            postcode: The postcode to look up
            
        Returns:
            Optional[Dict]: Dictionary containing postcode data or None if not found
        """
        try:
            response = requests.get(f"{PostcodeService.BASE_URL}/postcodes/{postcode}")
            if response.status_code == 200:
                data = response.json()
                return data.get('result')
            return None
        except Exception as e:
            logger.error(f"Error getting postcode data: {e}")
            return None
    
    @staticmethod
    def calculate_distance(start_postcode: str, end_postcode: str) -> Optional[float]:
        """
        Calculates the distance in miles between two UK postcodes.
        
        Args:
            start_postcode: The starting postcode
            end_postcode: The ending postcode
            
        Returns:
            Optional[float]: Distance in miles or None if calculation fails
        """
        try:
            start_data = PostcodeService.get_postcode_data(start_postcode)
            end_data = PostcodeService.get_postcode_data(end_postcode)
            
            if not start_data or not end_data:
                return None
                
            # Extract coordinates
            start_lat = start_data.get('latitude')
            start_lon = start_data.get('longitude')
            end_lat = end_data.get('latitude')
            end_lon = end_data.get('longitude')
            
            if None in (start_lat, start_lon, end_lat, end_lon):
                return None
            
            # Convert to float - we've already checked for None values above
            try:
                # Cast each value to float directly - we know they're not None at this point
                start_lat_float = float(start_lat)
                start_lon_float = float(start_lon)
                end_lat_float = float(end_lat)  
                end_lon_float = float(end_lon)
            except (ValueError, TypeError):
                logger.error(f"Could not convert coordinates to float: {start_lat}, {start_lon}, {end_lat}, {end_lon}")
                return None
                
            # Calculate distance using Haversine formula
            distance_km = PostcodeService._haversine(
                start_lat_float, start_lon_float, end_lat_float, end_lon_float
            )
            
            # Convert to miles (1 km = 0.621371 miles)
            distance_miles = distance_km * 0.621371
            
            # Round to 2 decimal places
            return round(distance_miles, 2)
            
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
