#!/usr/bin/env python3

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from postcode_service import PostcodeService
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)

def test_postcode_lookup():
    """Test postcode lookup with known UK coordinates"""
    print("Testing PostcodeService...")
    
    # London coordinates (same as we tested with curl)
    lat, lon = 51.5074, -0.1278
    
    print(f"Looking up postcode for coordinates: {lat}, {lon}")
    
    try:
        postcode = PostcodeService.get_postcode_from_coordinates(lat, lon)
        if postcode:
            print(f"✅ Found postcode: {postcode}")
            return True
        else:
            print("❌ No postcode found")
            return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_postcode_lookup()
    sys.exit(0 if success else 1) 