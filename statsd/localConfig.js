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
// Expire idle timers and sets too, so metric names carrying high-cardinality
// values (e.g. repohub's per-repo/-project timer names) do not accumulate keys
// in memory forever and OOM the sidecar. Without this, deleteTimers/deleteSets
// default to false and only gauges/counters are reclaimed each flush.
, deleteTimers: true
, deleteSets: true
}
