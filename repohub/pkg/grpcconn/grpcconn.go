// Package grpcconn provides a small, process-wide pool of reusable gRPC client
// connections, keyed by target address.
//
// A *grpc.ClientConn is itself a pool — it multiplexes many RPCs over one HTTP/2
// connection and reconnects automatically — so reusing a long-lived connection
// per target avoids a handshake per request (and the auth_context repo-proxy's
// insecure server leaked per handshake).
//
// Targets sit behind single-VIP Services, so kube-proxy balances per connection,
// not per RPC; keeping a few connections per target (DefaultPoolSize) spreads
// load across pods.
package grpcconn

import (
	"errors"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/keepalive"
)

const (
	// DefaultPoolSize is the per-target connection count when
	// REPOHUB_GRPC_CONN_POOL_SIZE is unset/invalid — sized so kube-proxy spreads
	// connections across pods (one connection would pin to a single pod).
	DefaultPoolSize = 5

	// MaxPoolSize caps EnvPoolSize against a misconfigured env var.
	MaxPoolSize = 32

	poolSizeEnvVar = "REPOHUB_GRPC_CONN_POOL_SIZE"
)

// ErrPoolClosed is returned by Get once the pool has been Close()d.
var ErrPoolClosed = errors.New("grpcconn: pool is closed")

// serviceConfig enables retries and round-robin.
//
// round_robin is a no-op on a single-VIP target (spread comes from the pool);
// it's kept so the client fans out automatically against a headless Service.
//
// Retries are limited to UNAVAILABLE (never DEADLINE_EXCEEDED, which would double
// tail latency) and are safe: the Describe lookups are reads, and GetToken/
// GetRepositoryToken return a token repo-proxy caches by installation id, so a
// retry returns the same cached token.
const serviceConfig = `{
  "loadBalancingConfig": [{"round_robin": {}}],
  "methodConfig": [{
    "name": [{}],
    "retryPolicy": {
      "maxAttempts": 3,
      "initialBackoff": "0.1s",
      "maxBackoff": "1s",
      "backoffMultiplier": 2,
      "retryableStatusCodes": ["UNAVAILABLE"]
    }
  }]
}`

// defaultDialOptions returns the options used when New is called without any.
//
// PermitWithoutStream is false so idle connections are never pinged: repo-proxy's
// Ruby (C-core) server sends GOAWAY "too_many_pings" for frequent idle pings.
// Dead backends are handled by the per-RPC deadline + retry instead.
func defaultDialOptions() []grpc.DialOption {
	return []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithDefaultServiceConfig(serviceConfig),
		grpc.WithKeepaliveParams(keepalive.ClientParameters{
			Time:                20 * time.Second,
			Timeout:             10 * time.Second,
			PermitWithoutStream: false,
		}),
	}
}

// Pool keeps a fixed number of long-lived connections per target address and
// hands them out round-robin. It is safe for concurrent use.
type Pool struct {
	size int
	opts []grpc.DialOption

	mu      sync.RWMutex
	closed  bool
	targets map[string]*targetConns
}

type targetConns struct {
	conns []*grpc.ClientConn
	next  atomic.Int64
}

// New returns a Pool that keeps size connections per target (size < 1 is treated
// as 1). With no dial options it uses defaultDialOptions.
func New(size int, opts ...grpc.DialOption) *Pool {
	if size < 1 {
		size = 1
	}
	if len(opts) == 0 {
		opts = defaultDialOptions()
	}
	return &Pool{size: size, opts: opts, targets: map[string]*targetConns{}}
}

// Get returns a reusable connection for address, lazily creating the target's
// connections on first use. The connection is owned by the pool: do NOT Close it.
func (p *Pool) Get(address string) (*grpc.ClientConn, error) {
	p.mu.RLock()
	if p.closed {
		p.mu.RUnlock()
		return nil, ErrPoolClosed
	}
	t := p.targets[address]
	p.mu.RUnlock()

	if t == nil {
		var err error
		if t, err = p.add(address); err != nil {
			return nil, err
		}
	}

	// int64 round-robin index — a widening int->int64 conversion of len avoids
	// the int->uint32 overflow gosec flags (G115); len(conns) is 1..MaxPoolSize.
	next := t.next.Add(1) - 1
	return t.conns[next%int64(len(t.conns))], nil
}

// add dials and caches the connections for a target, guarding against several
// goroutines creating the same target concurrently.
func (p *Pool) add(address string) (*targetConns, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.closed {
		return nil, ErrPoolClosed
	}
	if t := p.targets[address]; t != nil { // lost the race — reuse the winner
		return t, nil
	}

	conns := make([]*grpc.ClientConn, 0, p.size)
	for i := 0; i < p.size; i++ {
		// grpc.NewClient is lazy: it connects on the first RPC and reconnects
		// automatically, so the connection is safe to keep for the process life.
		conn, err := grpc.NewClient(address, p.opts...)
		if err != nil {
			for _, c := range conns {
				_ = c.Close()
			}
			return nil, fmt.Errorf("grpcconn: dialing %q: %w", address, err)
		}
		conns = append(conns, conn)
	}

	t := &targetConns{conns: conns}
	p.targets[address] = t
	return t, nil
}

// Close shuts down every pooled connection and empties the pool. After Close,
// Get returns ErrPoolClosed. Intended to be called once at shutdown.
func (p *Pool) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	p.closed = true

	var firstErr error
	for address, t := range p.targets {
		for _, c := range t.conns {
			if err := c.Close(); err != nil && firstErr == nil {
				firstErr = err
			}
		}
		delete(p.targets, address)
	}
	return firstErr
}

// Default is the process-wide pool behind the package-level Get; its size comes
// from REPOHUB_GRPC_CONN_POOL_SIZE (see EnvPoolSize).
var Default = New(EnvPoolSize())

// EnvPoolSize returns the pool size from REPOHUB_GRPC_CONN_POOL_SIZE, falling
// back to DefaultPoolSize when unset/invalid and clamping to MaxPoolSize.
func EnvPoolSize() int {
	raw := os.Getenv(poolSizeEnvVar)
	if raw == "" {
		return DefaultPoolSize
	}

	n, err := strconv.Atoi(raw)
	if err != nil || n < 1 {
		log.Printf("grpcconn: ignoring invalid %s=%q, using default %d", poolSizeEnvVar, raw, DefaultPoolSize)
		return DefaultPoolSize
	}
	if n > MaxPoolSize {
		log.Printf("grpcconn: clamping %s=%d to max %d", poolSizeEnvVar, n, MaxPoolSize)
		return MaxPoolSize
	}
	return n
}

// Get returns a reusable connection for address from the Default pool.
func Get(address string) (*grpc.ClientConn, error) {
	return Default.Get(address)
}
