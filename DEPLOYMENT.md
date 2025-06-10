# PostcodeTracker Server Deployment Guide

## Quick Start

### 1. Upload Files to Server
Transfer all files to your server at `rickys.ddns.net`.

### 2. Install Dependencies
```bash
# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Start the Server
```bash
# Simple startup
./start_server.sh

# Or manually with gunicorn
gunicorn --config gunicorn.conf.py app:app
```

The server will be available at: `http://rickys.ddns.net:8005`

## Production Setup (Optional)

### Using systemd (Linux)
1. Edit the `postcode-tracker.service` file and update the paths:
   - Change `/path/to/your/PostcodeTracker` to your actual path
   - Update user/group as needed

2. Copy to systemd and enable:
```bash
sudo cp postcode-tracker.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable postcode-tracker
sudo systemctl start postcode-tracker
```

3. Check status:
```bash
sudo systemctl status postcode-tracker
```

## Configuration

### Environment Variables
- `FLASK_ENV`: Set to `production` for production deployment
- `PORT`: Server port (default: 8005)
- `SECRET_KEY`: Flask secret key (will be auto-generated if not set)
- `JWT_SECRET_KEY`: JWT signing key (will be auto-generated if not set)
- `DATABASE_URL`: Database URL (defaults to SQLite)

### Firewall
Make sure port 8005 is open on your server:
```bash
# Ubuntu/Debian
sudo ufw allow 8005

# CentOS/RHEL
sudo firewall-cmd --permanent --add-port=8005/tcp
sudo firewall-cmd --reload
```

## API Endpoints

The server provides these endpoints:
- `GET /api/health` - Health check
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/journey/start` - Start a journey
- `POST /api/journey/end` - End a journey
- `GET /api/journey/active` - Get active journey
- `GET /api/journeys` - Get journey history
- `GET /api/postcode/from-coordinates` - Get postcode from coordinates

## iOS App Configuration

The iOS app has been configured to connect to:
`http://rickys.ddns.net:8005/api`

No changes needed to the iOS app - just build and run! 