import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = 1  # Reduced to 1 for debugging
worker_class = 'uvicorn.workers.UvicornWorker'  # Using uvicorn worker for better HTTP/1.1 support
worker_connections = 1000
timeout = 30
keepalive = 65

# HTTP
http_version = "1.1"
forwarded_allow_ips = "*"
proxy_protocol = False
proxy_allow_ips = "*"

# Response headers
response_headers = [
    ('X-Content-Type-Options', 'nosniff'),
    ('X-Frame-Options', 'DENY'),
    ('X-XSS-Protection', '1; mode=block'),
    ('Content-Type', 'application/json'),
    ('Connection', 'keep-alive'),
    ('Keep-Alive', 'timeout=65'),
    ('X-Protocol', 'HTTP/1.1'),
]

# Logging
accesslog = "-"  # Log to stdout
errorlog = "-"   # Log to stderr
loglevel = "debug"  # Increased log level

# Process naming
proc_name = "postcode_tracker"

# SSL (uncomment and configure if using HTTPS)
# keyfile = "path/to/keyfile"
# certfile = "path/to/certfile" 