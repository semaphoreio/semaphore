// Package ratelimit provides a per-organization, per-pod, in-memory rate
// limiter used to smooth bursty agent register/disconnect churn.
//
// The limiter is per-pod: the public API runs with several replicas, so the
// effective cluster-wide limit is roughly (per-pod limit) * (replica count).
// Callers should express the configured limit as a per-pod value.
//
// It is disabled by default. When disabled, Allow is a no-op that always
// returns true, so wiring it into a request path has no effect until it is
// explicitly turned on via configuration.
package ratelimit

import (
	"os"
	"strconv"
	"sync"
	"time"

	"golang.org/x/time/rate"
)

const (
	// DefaultPerSecond and DefaultBurst are per-pod defaults, only used when
	// the limiter is enabled. They are intentionally generous: the limiter
	// exists to clip pathological flapping, not to throttle healthy churn.
	DefaultPerSecond = 5.0
	DefaultBurst     = 10

	gcEvery = 10 * time.Minute
	idleFor = 30 * time.Minute
)

// Limiter is a per-organization token-bucket rate limiter.
type Limiter struct {
	enabled bool
	limit   rate.Limit
	burst   int

	mu      sync.Mutex
	buckets map[string]*bucket
	lastGC  time.Time

	// now is injectable for deterministic testing.
	now func() time.Time
}

type bucket struct {
	limiter  *rate.Limiter
	lastSeen time.Time
}

// New builds a limiter. When enabled is false the limiter is a no-op.
func New(enabled bool, perSecond float64, burst int) *Limiter {
	return &Limiter{
		enabled: enabled,
		limit:   rate.Limit(perSecond),
		burst:   burst,
		buckets: make(map[string]*bucket),
		now:     time.Now,
	}
}

// FromEnv builds a limiter from environment variables:
//
//	AGENT_RATE_LIMIT_ENABLED     - "true" to enable (default: disabled)
//	AGENT_RATE_LIMIT_PER_SECOND  - per-pod events/second (default: 5)
//	AGENT_RATE_LIMIT_BURST       - per-pod burst size (default: 10)
func FromEnv() *Limiter {
	enabled := os.Getenv("AGENT_RATE_LIMIT_ENABLED") == "true"
	perSecond := floatFromEnv("AGENT_RATE_LIMIT_PER_SECOND", DefaultPerSecond)
	burst := intFromEnv("AGENT_RATE_LIMIT_BURST", DefaultBurst)
	return New(enabled, perSecond, burst)
}

// Enabled reports whether the limiter actually enforces anything.
func (l *Limiter) Enabled() bool {
	return l != nil && l.enabled
}

// Allow consumes one token from the organization's bucket and reports whether
// the event may proceed. A nil or disabled limiter always allows.
func (l *Limiter) Allow(orgID string) bool {
	if l == nil || !l.enabled {
		return true
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	now := l.now()
	l.gc(now)

	b, ok := l.buckets[orgID]
	if !ok {
		b = &bucket{limiter: rate.NewLimiter(l.limit, l.burst)}
		l.buckets[orgID] = b
	}
	b.lastSeen = now

	return b.limiter.AllowN(now, 1)
}

// gc evicts buckets for organizations that have been idle, so the map does not
// grow without bound as organizations come and go. Caller must hold l.mu.
func (l *Limiter) gc(now time.Time) {
	if l.lastGC.IsZero() {
		l.lastGC = now
		return
	}

	if now.Sub(l.lastGC) < gcEvery {
		return
	}

	l.lastGC = now
	for org, b := range l.buckets {
		if now.Sub(b.lastSeen) > idleFor {
			delete(l.buckets, org)
		}
	}
}

func floatFromEnv(key string, def float64) float64 {
	raw := os.Getenv(key)
	if raw == "" {
		return def
	}

	value, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return def
	}

	return value
}

func intFromEnv(key string, def int) int {
	raw := os.Getenv(key)
	if raw == "" {
		return def
	}

	value, err := strconv.Atoi(raw)
	if err != nil {
		return def
	}

	return value
}
