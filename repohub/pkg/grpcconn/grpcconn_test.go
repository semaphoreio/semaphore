package grpcconn

import (
	"context"
	"net"
	"sync"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/resolver"
	"google.golang.org/grpc/resolver/manual"
)

// A syntactically valid target that never actually connects — grpc.NewClient is
// lazy, so Get succeeds without a live backend for the pure pool-mechanics tests.
const dummyTarget = "passthrough:///127.0.0.1:1"

func TestNew_SizeNormalization(t *testing.T) {
	for _, size := range []int{-3, 0} {
		if got := New(size).size; got != 1 {
			t.Errorf("New(%d).size = %d, want 1", size, got)
		}
	}
	if got := New(4).size; got != 4 {
		t.Errorf("New(4).size = %d, want 4", got)
	}
}

func TestPool_Get_ReusesConnections(t *testing.T) {
	p := New(1)
	defer p.Close()

	c1, err := p.Get(dummyTarget)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	c2, err := p.Get(dummyTarget)
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	if c1 != c2 {
		t.Error("size-1 pool returned two different connections for the same target")
	}

	p.mu.RLock()
	n := len(p.targets)
	p.mu.RUnlock()
	if n != 1 {
		t.Errorf("targets = %d, want 1", n)
	}
}

func TestPool_Get_DistinctTargets(t *testing.T) {
	p := New(1)
	defer p.Close()

	a, _ := p.Get("passthrough:///a:1")
	b, _ := p.Get("passthrough:///b:1")
	if a == b {
		t.Error("different targets shared a connection")
	}

	p.mu.RLock()
	n := len(p.targets)
	p.mu.RUnlock()
	if n != 2 {
		t.Errorf("targets = %d, want 2", n)
	}
}

func TestPool_Get_RoundRobin(t *testing.T) {
	const size = 3
	p := New(size)
	defer p.Close()

	counts := map[*grpc.ClientConn]int{}
	for i := 0; i < size*3; i++ {
		c, err := p.Get(dummyTarget)
		if err != nil {
			t.Fatalf("Get: %v", err)
		}
		counts[c]++
	}

	if len(counts) != size {
		t.Fatalf("round-robin touched %d connections, want %d", len(counts), size)
	}
	for c, n := range counts {
		if n != 3 {
			t.Errorf("connection %p served %d calls, want 3 (uneven round-robin)", c, n)
		}
	}
}

// Run under -race: 200 goroutines racing on the first Get of one target must
// produce exactly one target set of exactly `size` connections.
func TestPool_Get_ConcurrentFirstUse(t *testing.T) {
	const (
		size       = 4
		goroutines = 200
	)
	p := New(size)
	defer p.Close()

	var wg sync.WaitGroup
	wg.Add(goroutines)
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			if _, err := p.Get(dummyTarget); err != nil {
				t.Errorf("Get: %v", err)
			}
		}()
	}
	wg.Wait()

	p.mu.RLock()
	defer p.mu.RUnlock()
	if len(p.targets) != 1 {
		t.Fatalf("targets = %d, want 1", len(p.targets))
	}
	if got := len(p.targets[dummyTarget].conns); got != size {
		t.Errorf("conns = %d, want %d", got, size)
	}
}

func TestPool_Close(t *testing.T) {
	p := New(2)
	if _, err := p.Get(dummyTarget); err != nil {
		t.Fatalf("Get: %v", err)
	}

	if err := p.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	p.mu.RLock()
	n := len(p.targets)
	p.mu.RUnlock()
	if n != 0 {
		t.Errorf("targets after Close = %d, want 0", n)
	}

	// A closed pool must not lazily re-dial.
	if _, err := p.Get(dummyTarget); err != ErrPoolClosed {
		t.Errorf("Get after Close = %v, want ErrPoolClosed", err)
	}
}

func TestEnvPoolSize(t *testing.T) {
	// os.Getenv returns "" for both unset and empty, so the empty case covers the
	// "unset -> DefaultPoolSize" path too.
	tests := []struct {
		name string
		val  string
		want int
	}{
		{name: "empty", val: "", want: DefaultPoolSize},
		{name: "valid", val: "9", want: 9},
		{name: "zero", val: "0", want: DefaultPoolSize},
		{name: "negative", val: "-2", want: DefaultPoolSize},
		{name: "garbage", val: "abc", want: DefaultPoolSize},
		{name: "at max", val: "32", want: MaxPoolSize},
		{name: "over max clamps", val: "100000", want: MaxPoolSize},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv(poolSizeEnvVar, tc.val)
			if got := EnvPoolSize(); got != tc.want {
				t.Errorf("EnvPoolSize() = %d, want %d", got, tc.want)
			}
		})
	}
}

// TestPool_Failover_RoundRobin exercises the default dial options (round-robin +
// retry-on-UNAVAILABLE + keepalive) against three live backends behind a manual
// resolver, then kills backends and asserts calls keep succeeding.
func TestPool_Failover_RoundRobin(t *testing.T) {
	const scheme = "grpcconn-failover-test"

	backends := []*healthBackend{
		startHealthBackend(t),
		startHealthBackend(t),
		startHealthBackend(t),
	}

	r := manual.NewBuilderWithScheme(scheme)
	resolver.Register(r)
	addrs := make([]resolver.Address, len(backends))
	for i, b := range backends {
		addrs[i] = resolver.Address{Addr: b.addr}
	}
	r.InitialState(resolver.State{Addresses: addrs})

	// One connection, so round_robin fans it out across the resolver's addresses.
	p := New(1)
	defer p.Close()

	conn, err := p.Get(scheme + ":///backends")
	if err != nil {
		t.Fatalf("Get: %v", err)
	}
	client := healthpb.NewHealthClient(conn)

	check := func() error {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, err := client.Check(ctx, &healthpb.HealthCheckRequest{})
		return err
	}

	waitReady(t, check)

	// round-robin should fan out across all three backends.
	for i := 0; i < 30; i++ {
		if err := check(); err != nil {
			t.Fatalf("healthy call %d failed: %v", i, err)
		}
	}
	for i, b := range backends {
		if b.connections() == 0 {
			t.Errorf("backend %d received no connection; round-robin did not fan out", i)
		}
	}

	// Kill one backend: round-robin ejects it and retry-on-UNAVAILABLE covers the
	// in-flight call that raced the shutdown. All calls must still succeed.
	backends[0].stop()
	for i := 0; i < 30; i++ {
		if err := check(); err != nil {
			t.Fatalf("call %d after killing 1/3 backends failed: %v", i, err)
		}
	}

	// Kill a second backend: calls recover onto the sole survivor.
	backends[1].stop()
	for i := 0; i < 30; i++ {
		if err := check(); err != nil {
			t.Fatalf("call %d after killing 2/3 backends failed: %v", i, err)
		}
	}
}

type healthBackend struct {
	addr string
	srv  *grpc.Server

	mu       sync.Mutex
	accepted int
}

func (b *healthBackend) connections() int {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.accepted
}

func (b *healthBackend) stop() { b.srv.Stop() }

func startHealthBackend(t *testing.T) *healthBackend {
	t.Helper()

	lis, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen: %v", err)
	}

	b := &healthBackend{addr: lis.Addr().String()}

	srv := grpc.NewServer()
	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(srv, hs)
	b.srv = srv

	counting := &countingListener{Listener: lis, onAccept: func() {
		b.mu.Lock()
		b.accepted++
		b.mu.Unlock()
	}}

	go func() { _ = srv.Serve(counting) }()
	t.Cleanup(srv.Stop)

	return b
}

type countingListener struct {
	net.Listener
	onAccept func()
}

func (l *countingListener) Accept() (net.Conn, error) {
	c, err := l.Listener.Accept()
	if err == nil {
		l.onAccept()
	}
	return c, err
}

func waitReady(t *testing.T, call func() error) {
	t.Helper()

	const (
		timeout = 5 * time.Second
		step    = 50 * time.Millisecond
	)
	for waited := time.Duration(0); waited < timeout; waited += step {
		if call() == nil {
			return
		}
		time.Sleep(step)
	}
	t.Fatal("backends never became ready")
}
