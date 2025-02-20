# statsd

## Environment variables

- FLUSH_INTERVAL = [milliseconds] agregates are sent to sink with this period (recomended 60000)
- GRAPHITE_HOST  = Sink address (IP or DNS)
- DUMP_MESSAGES  = ["true" or "false"] If true all received UDP messages are printed (a lot of output)
