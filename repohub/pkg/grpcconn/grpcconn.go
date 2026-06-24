// Package grpcconn provides a small, process-wide pool of reusable gRPC client
// connections, keyed by target address.
//
// A *grpc.ClientConn is safe for concurrent use, multiplexes many in-flight
// RPCs over a single HTTP/2 connection, and transparently reconnects — it is
// itself a connection pool. Dialing a fresh ClientConn per request (and closing
// it afterwards) therefore pays a full TCP + HTTP/2 handshake on every call,
// and against repo-proxy's insecure gRPC server it leaked one auth_context per
// handshake. Reusing a long-lived connection per target removes that churn.
package grpcconn

import (
	"fmt"
	"sync"
	"sync/atomic"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Pool keeps a fixed number of long-lived connections per target address and
// hands them out round-robin. It is safe for concurrent use.
type Pool struct {
	size int
	opts []grpc.DialOption

	mu      sync.RWMutex
	targets map[string]*targetConns
}

type targetConns struct {
	conns []*grpc.ClientConn
	next  uint32
}

// New returns a Pool that keeps size connections per target (size < 1 is
// treated as 1). When no dial options are given it defaults to insecure
// transport credentials, matching repohub's plaintext internal APIs.
func New(size int, opts ...grpc.DialOption) *Pool {
	if size < 1 {
		size = 1
	}
	if len(opts) == 0 {
		opts = []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
	}
	return &Pool{size: size, opts: opts, targets: map[string]*targetConns{}}
}

// Get returns a reusable connection for address, lazily creating the target's
// connections on first use. The returned connection is shared and owned by the
// pool: callers must NOT Close it.
func (p *Pool) Get(address string) (*grpc.ClientConn, error) {
	p.mu.RLock()
	t := p.targets[address]
	p.mu.RUnlock()

	if t == nil {
		var err error
		if t, err = p.add(address); err != nil {
			return nil, err
		}
	}

	idx := (atomic.AddUint32(&t.next, 1) - 1) % uint32(len(t.conns))
	return t.conns[idx], nil
}

// add dials and caches the connections for a target, guarding against a race
// where several goroutines create the same target concurrently.
func (p *Pool) add(address string) (*targetConns, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

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

// Close shuts down every pooled connection and empties the pool. Intended to be
// called once during graceful shutdown.
func (p *Pool) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()

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

// Default is the process-wide pool used by the package-level Get. It keeps a
// single (multiplexed) connection per target, which is enough for repohub's
// traffic while eliminating per-request dialing.
var Default = New(1)

// Get returns a reusable connection for address from the Default pool.
func Get(address string) (*grpc.ClientConn, error) {
	return Default.Get(address)
}
