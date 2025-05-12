import io
import csv
import logging
import pandas as pd
from typing import List, Dict, Any, Optional
from models import Journey

logger = logging.getLogger(__name__)

def get_journey_data(journey_ids: Optional[List[int]] = None) -> List[Dict[str, Any]]:
    """
    Get journey data in a format suitable for export.
    
    Args:
        journey_ids: Optional list of journey IDs to filter by
        
    Returns:
        List of journey data dictionaries
    """
    try:
        query = Journey.query
        
        # If specific journey IDs were provided, filter by them
        if journey_ids:
            query = query.filter(Journey.id.in_(journey_ids))
        else:
            # Otherwise, get all completed journeys
            query = query.filter(Journey.end_time.isnot(None))
            
        # Order by most recent first
        journeys = query.order_by(Journey.end_time.desc()).all()
        
        # Format the data for export
        journey_data = []
        for journey in journeys:
            journey_data.append({
                'ID': journey.id,
                'Start Postcode': journey.start_postcode,
                'End Postcode': journey.end_postcode,
                'Start Time': journey.start_time.strftime('%Y-%m-%d %H:%M:%S') if journey.start_time else '',
                'End Time': journey.end_time.strftime('%Y-%m-%d %H:%M:%S') if journey.end_time else '',
                'Distance (miles)': journey.distance_miles if journey.distance_miles else 0
            })
            
        return journey_data
    
    except Exception as e:
        logger.error(f"Error getting journey data for export: {e}")
        return []

def export_to_csv(journey_ids: Optional[List[int]] = None) -> Optional[io.StringIO]:
    """
    Export journey data to CSV format.
    
    Args:
        journey_ids: Optional list of journey IDs to export
        
    Returns:
        StringIO object containing CSV data or None if export fails
    """
    try:
        journey_data = get_journey_data(journey_ids)
        
        if not journey_data:
            return None
            
        output = io.StringIO()
        fieldnames = journey_data[0].keys()
        
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(journey_data)
        
        output.seek(0)
        return output
        
    except Exception as e:
        logger.error(f"Error exporting to CSV: {e}")
        return None

def export_to_excel(journey_ids: Optional[List[int]] = None) -> Optional[io.BytesIO]:
    """
    Export journey data to Excel format.
    
    Args:
        journey_ids: Optional list of journey IDs to export
        
    Returns:
        BytesIO object containing Excel data or None if export fails
    """
    try:
        journey_data = get_journey_data(journey_ids)
        
        if not journey_data:
            return None
            
        # Convert to DataFrame
        df = pd.DataFrame(journey_data)
        
        # Create temporary file for Excel
        import tempfile
        with tempfile.NamedTemporaryFile(suffix='.xlsx', delete=False) as tmp:
            temp_filename = tmp.name
        
        # Write DataFrame to Excel file
        df.to_excel(temp_filename, sheet_name='Journey History', index=False, engine='openpyxl')
        
        # Read the file back into memory
        output = io.BytesIO()
        with open(temp_filename, 'rb') as file:
            output.write(file.read())
        
        # Clean up the temporary file
        import os
        os.unlink(temp_filename)
        
        output.seek(0)
        return output
        
    except Exception as e:
        logger.error(f"Error exporting to Excel: {e}")
        return None