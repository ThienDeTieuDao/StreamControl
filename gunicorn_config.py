# Gunicorn configuration file
# This file contains configuration for running StreamLite in production

import os
import multiprocessing

# Bind to port 5000 on all interfaces for accessibility
bind = "0.0.0.0:5000"

# Set the number of worker processes
# Recommended formula is 2-4 x number of CPU cores
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"

# Set timeout for worker processes
timeout = 300  # 5 minutes for uploading large files

# Set keepalive for worker processes
keepalive = 5

# Logging configuration
errorlog = "/var/log/streamlite/error.log"
accesslog = "/var/log/streamlite/access.log"
loglevel = "info"

# Create log directory if it doesn't exist
log_dir = "/var/log/streamlite"
if not os.path.exists(log_dir):
    try:
        os.makedirs(log_dir)
    except:
        # Fallback to current directory if we can't create log dir
        errorlog = "error.log"
        accesslog = "access.log"

# Process name
proc_name = "streamlite"

# Protect against the MIME-type security vulnerability
forwarded_allow_ips = "*"

# Maximum request size (1GB for video uploads)
limit_request_line = 8190
limit_request_fields = 100
limit_request_field_size = 8190

# Preload application for memory efficiency
preload_app = True

# Environmental variables to set when launching Gunicorn
raw_env = [
    "FFMPEG_PATH=/usr/bin/ffmpeg",
    "FFPROBE_PATH=/usr/bin/ffprobe"
]

# Handle startup error
def on_starting(server):
    server.log.info("Starting StreamLite server")

# Clean up on exit
def on_exit(server):
    server.log.info("Shutting down StreamLite server")

# Customize these functions if specific initialization is needed
def post_fork(server, worker):
    server.log.info("Worker spawned (pid: %s)", worker.pid)

def pre_fork(server, worker):
    pass

def pre_exec(server):
    server.log.info("Forked child, re-executing")

def when_ready(server):
    server.log.info("Server is ready. Spawning workers")

def worker_int(worker):
    worker.log.info("worker received INT or QUIT signal")

def worker_abort(worker):
    worker.log.info("Worker received SIGABRT signal")

def worker_exit(server, worker):
    server.log.info("Worker exited (pid: %s)", worker.pid)
