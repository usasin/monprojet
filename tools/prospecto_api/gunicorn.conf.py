bind = '0.0.0.0:8000'
workers = 2
worker_class = 'gthread'
threads = 4
timeout = 30
graceful_timeout = 30
keepalive = 2
max_requests = 10000
max_requests_jitter = 500
# Do not log precise locations, business searches, or IPs.
accesslog = None
errorlog = '-'
loglevel = 'warning'
limit_request_line = 4094
limit_request_fields = 30
limit_request_field_size = 4094
forwarded_allow_ips = ''
worker_tmp_dir = '/tmp'
