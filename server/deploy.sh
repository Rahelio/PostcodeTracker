#!/bin/bash

# Exit on error
set -e

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create virtual environment if it doesn't exist
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Create logs directory
mkdir -p logs

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file..."
    cat > .env << EOL
DATABASE_URL=postgresql://username:password@localhost:5432/dbname
JWT_SECRET_KEY=$(openssl rand -hex 32)
EOL
    echo "Please update the .env file with your actual database credentials"
fi

# Create systemd service file
echo "Creating systemd service file..."
sudo cp "$SCRIPT_DIR/postcode-tracker.service" /etc/systemd/system/
sudo sed -i "s|YOUR_USERNAME|$USER|g" /etc/systemd/system/postcode-tracker.service
sudo sed -i "s|YOUR_GROUP|$(id -gn)|g" /etc/systemd/system/postcode-tracker.service
sudo sed -i "s|/path/to/your/app|$(pwd)|g" /etc/systemd/system/postcode-tracker.service
sudo sed -i "s|/path/to/your/venv|$(pwd)/venv|g" /etc/systemd/system/postcode-tracker.service

# Reload systemd
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl enable postcode-tracker
sudo systemctl start postcode-tracker

echo "Deployment complete! Check the service status with: sudo systemctl status postcode-tracker" 