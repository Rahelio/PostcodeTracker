#!/bin/bash

# PostcodeTracker Server Startup Script

echo "Starting PostcodeTracker server..."

# Set environment variables
export FLASK_ENV=production
export PORT=8005

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Install/update dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Start the server with gunicorn
echo "Starting gunicorn server on port 8005..."
gunicorn --config gunicorn.conf.py app:app 