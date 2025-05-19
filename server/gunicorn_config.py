import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = 1  # Reduced to 1 for debugging
worker_class = 'sync'
worker_connections = 1000
timeout = 30
keepalive = 2

# HTTP
http_version = "1.1"
forwarded_allow_ips = "*"
proxy_protocol = False
proxy_allow_ips = "*"

# Logging
accesslog = "-"  # Log to stdout
errorlog = "-"   # Log to stderr
loglevel = "debug"  # Increased log level

# Process naming
proc_name = "postcode_tracker"

# SSL (uncomment and configure if using HTTPS)
# keyfile = "path/to/keyfile"
# certfile = "path/to/certfile" 