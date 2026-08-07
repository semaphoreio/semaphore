package ratelimit

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// Disabled limiter must never block, no matter how many events arrive.
// This is the positive path for the default configuration: healthy churn is
// untouched unless the feature is explicitly turned on.
func Test__Disabled_AlwaysAllows(t *testing.T) {
	l := New(false, 1, 1)

	for i := 0; i < 1000; i++ {
		require.True(t, l.Allow("org-1"), "disabled limiter must allow every event")
	}

	require.False(t, l.Enabled())
}

// A nil limiter is treated as disabled.
func Test__Nil_AlwaysAllows(t *testing.T) {
	var l *Limiter
	require.True(t, l.Allow("org-1"))
	require.False(t, l.Enabled())
}

// Enabled limiter allows up to the burst, then blocks further events for the
// same org until the bucket refills.
func Test__Enabled_BurstThenBlock(t *testing.T) {
	now := time.Now()
	l := New(true, 0.0001, 3) // ~no refill within the test window
	l.now = func() time.Time { return now }

	require.True(t, l.Allow("org-1"))
	require.True(t, l.Allow("org-1"))
	require.True(t, l.Allow("org-1"))
	require.False(t, l.Allow("org-1"), "4th event over a burst of 3 must be blocked")
	require.False(t, l.Allow("org-1"))
}

// Per-org isolation: exhausting one org's bucket must not affect another org.
// This is the "normal churn for other tenants is unaffected" guarantee.
func Test__Enabled_PerOrgIsolation(t *testing.T) {
	now := time.Now()
	l := New(true, 0.0001, 1)
	l.now = func() time.Time { return now }

	require.True(t, l.Allow("org-1"))
	require.False(t, l.Allow("org-1"), "org-1 is now exhausted")

	// A different org has its own independent bucket.
	require.True(t, l.Allow("org-2"))
	require.False(t, l.Allow("org-2"))
}

// Tokens refill over time, so a throttled org recovers.
func Test__Enabled_RefillsOverTime(t *testing.T) {
	now := time.Now()
	l := New(true, 10, 1) // 10/s => 1 token every 100ms
	l.now = func() time.Time { return now }

	require.True(t, l.Allow("org-1"))
	require.False(t, l.Allow("org-1"))

	// Advance the clock enough to refill one token.
	now = now.Add(200 * time.Millisecond)
	require.True(t, l.Allow("org-1"), "bucket should have refilled after 200ms")
}

// Idle org buckets are evicted so the map cannot grow without bound.
func Test__IdleBucketsAreEvicted(t *testing.T) {
	now := time.Now()
	l := New(true, 1, 1)
	l.now = func() time.Time { return now }

	require.True(t, l.Allow("org-1"))
	require.Len(t, l.buckets, 1)

	// Move past the GC interval and the idle threshold, then touch a different
	// org to trigger a GC pass.
	now = now.Add(gcEvery + idleFor + time.Minute)
	require.True(t, l.Allow("org-2"))

	_, org1Present := l.buckets["org-1"]
	require.False(t, org1Present, "idle org-1 bucket should be evicted")
	require.Contains(t, l.buckets, "org-2")
}

func Test__FromEnv_DefaultsDisabled(t *testing.T) {
	t.Setenv("AGENT_RATE_LIMIT_ENABLED", "")
	l := FromEnv()
	require.False(t, l.Enabled())
	require.True(t, l.Allow("org-1"))
}

func Test__FromEnv_Enabled(t *testing.T) {
	t.Setenv("AGENT_RATE_LIMIT_ENABLED", "true")
	t.Setenv("AGENT_RATE_LIMIT_PER_SECOND", "0.0001")
	t.Setenv("AGENT_RATE_LIMIT_BURST", "2")
	l := FromEnv()
	require.True(t, l.Enabled())

	require.True(t, l.Allow("org-1"))
	require.True(t, l.Allow("org-1"))
	require.False(t, l.Allow("org-1"))
}
