import multiprocessing

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = 'sync'
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
accesslog = '-'
errorlog = '-'
loglevel = 'debug'

# Process naming
proc_name = 'postcode_tracker'

# Server mechanics
daemon = False
pidfile = None
umask = 0
user = None
group = None
tmp_upload_dir = None

# SSL
keyfile = None
certfile = None

# HTTP
protocol_version = "HTTP/1.1"
forwarded_allow_ips = '*'
proxy_protocol = False
proxy_allow_ips = '*'

# Server hooks
def on_starting(server):
    server.log.info("Starting Gunicorn server with HTTP/1.1 support")

def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def pre_fork(server, worker):
    pass

def pre_exec(server):
    server.log.info("Forked child, re-executing.")

def when_ready(server):
    server.log.info("Server is ready. Spawning workers")

# Additional settings
raw_env = [
    'PYTHONUNBUFFERED=1',
    'FLASK_ENV=production',
    'FLASK_APP=wsgi.py'
] 