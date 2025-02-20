{
  port: 8125
, graphiteHost: process.env.GRAPHITE_HOST
, graphitePort: 2003
, graphite: {
    legacyNamespace: false
  }
, backends: ["./backends/graphite"]
, debug: true
, dumpMessages: (process.env.DUMP_MESSAGES == 'true')
, flushInterval: parseInt(process.env.FLUSH_INTERVAL)  // Should be synchronised with metric source
, deleteGauges: true
, deleteCounters: true
}
