# Gunicorn configuration file for PostcodeTracker
import os

# Server socket
bind = "0.0.0.0:8005"
backlog = 2048

# Worker processes
workers = 4
worker_class = "sync"
worker_connections = 1000
timeout = 60
keepalive = 2

# Restart workers after this many requests, to help prevent memory leaks
max_requests = 1000
max_requests_jitter = 100

# Logging
accesslog = "-"  # Log to stdout
errorlog = "-"   # Log to stderr
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

# Process naming
proc_name = 'postcode_tracker'

# Server mechanics
daemon = False
pidfile = '/tmp/postcode_tracker.pid'
user = None
group = None
tmp_upload_dir = None

# SSL (uncomment and configure if you want HTTPS)
# keyfile = '/path/to/keyfile'
# certfile = '/path/to/certfile'

# Environment variables
raw_env = [
    'FLASK_ENV=production',
] 