package emitter

import (
	"errors"
	"os"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	rabbit "github.com/rabbitmq/amqp091-go"
	"github.com/renderedtext/go-tackle"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var errBrokerDown = errors.New("broker is down")

func testEmitterOptions() tackle.Options {
	return tackle.Options{
		URL:            os.Getenv("RABBITMQ_URL"),
		ConnectionName: "velocity.pending_metrics_emitter.test",
		RemoteExchange: "velocity_emitter_test_exchange",
		RoutingKey:     "done",
	}
}

func testEmitter(connect func() (*rabbit.Connection, error)) *PendingMetricsEmitter {
	emitter := NewPendingMetricsEmitter(testEmitterOptions(), nil, "0 8 * * *")
	emitter.publisherOptions.ConnectFunc = connect
	return emitter
}

func requireBroker(t *testing.T) {
	if os.Getenv("RABBITMQ_URL") == "" {
		t.Skip("RABBITMQ_URL not set; skipping broker integration test")
	}
}

func TestPublisherDialsOncePerTick(t *testing.T) {
	requireBroker(t)

	var dials int32

	emitter := testEmitter(func() (*rabbit.Connection, error) {
		atomic.AddInt32(&dials, 1)
		return rabbit.Dial(testEmitterOptions().URL)
	})

	require.NoError(t, emitter.openPublisher())
	defer emitter.closePublisher()

	wg := new(sync.WaitGroup)
	errs := make(chan error, 200)

	for i := 0; i < 200; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := emitter.publishMessage([]byte("pending metric")); err != nil {
				errs <- err
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		t.Errorf("publish failed: %v", err)
	}

	assert.Equal(t, int32(1), atomic.LoadInt32(&dials))
}

func TestPublisherReconnectsAfterConnectionDrop(t *testing.T) {
	requireBroker(t)

	conns := make([]*rabbit.Connection, 0, 2)

	emitter := testEmitter(func() (*rabbit.Connection, error) {
		conn, err := rabbit.Dial(testEmitterOptions().URL)
		if err != nil {
			return nil, err
		}

		conns = append(conns, conn)
		return conn, nil
	})

	require.NoError(t, emitter.openPublisher())
	defer emitter.closePublisher()

	require.NoError(t, emitter.publishMessage([]byte("before the drop")))
	require.Len(t, conns, 1)

	require.NoError(t, conns[0].Close())

	require.NoError(t, emitter.publishMessage([]byte("after the drop")))
	assert.Len(t, conns, 2)
}

func TestPublisherClosesConnectionAtEndOfTick(t *testing.T) {
	requireBroker(t)

	var conn *rabbit.Connection

	emitter := testEmitter(func() (*rabbit.Connection, error) {
		var err error
		conn, err = rabbit.Dial(testEmitterOptions().URL)
		return conn, err
	})

	require.NoError(t, emitter.openPublisher())
	require.NoError(t, emitter.publishMessage([]byte("pending metric")))

	emitter.closePublisher()

	assert.Nil(t, emitter.publisher)
	assert.True(t, conn.IsClosed())
}

func TestOpenPublisherFailsFastWhenBrokerIsUnreachable(t *testing.T) {
	options := testEmitterOptions()
	options.URL = "amqp://guest:guest@10.255.255.1:5672"

	emitter := NewPendingMetricsEmitter(options, nil, "0 8 * * *")
	require.Equal(t, defaultConnectionTimeout, emitter.publisherOptions.ConnectionTimeout)
	emitter.publisherOptions.ConnectionTimeout = 300 * time.Millisecond

	start := time.Now()
	err := emitter.openPublisher()
	elapsed := time.Since(start)

	require.Error(t, err)
	assert.Nil(t, emitter.publisher)
	assert.Less(t, elapsed, 3*time.Second)
}

func TestPublishStaysBoundedWhenBrokerDiesMidTick(t *testing.T) {
	requireBroker(t)

	var dials int32
	var conn *rabbit.Connection

	emitter := testEmitter(func() (*rabbit.Connection, error) {
		if atomic.AddInt32(&dials, 1) > 1 {
			return nil, errBrokerDown
		}

		var err error
		conn, err = rabbit.Dial(testEmitterOptions().URL)
		return conn, err
	})
	emitter.publishTimeout = time.Second

	require.NoError(t, emitter.openPublisher())
	defer emitter.closePublisher()
	require.NoError(t, conn.Close())

	wg := new(sync.WaitGroup)
	failures := make(chan error, 20)

	start := time.Now()
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			failures <- emitter.publishMessage([]byte("pending metric"))
		}()
	}

	wg.Wait()
	close(failures)
	elapsed := time.Since(start)

	for err := range failures {
		assert.Error(t, err)
	}

	assert.Less(t, elapsed, 5*time.Second)
}

func TestConcurrentReconnectAfterLiveDropIsRaceFree(t *testing.T) {
	requireBroker(t)

	var mu sync.Mutex
	var conns []*rabbit.Connection

	emitter := testEmitter(func() (*rabbit.Connection, error) {
		conn, err := rabbit.Dial(testEmitterOptions().URL)
		if err != nil {
			return nil, err
		}

		mu.Lock()
		conns = append(conns, conn)
		mu.Unlock()
		return conn, nil
	})

	require.NoError(t, emitter.openPublisher())
	defer emitter.closePublisher()

	require.NoError(t, emitter.publishMessage([]byte("establish connection")))
	mu.Lock()
	require.Len(t, conns, 1)
	first := conns[0]
	mu.Unlock()

	require.NoError(t, first.Close())

	wg := new(sync.WaitGroup)
	errs := make(chan error, 50)

	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := emitter.publishMessage([]byte("after live drop")); err != nil {
				errs <- err
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		t.Errorf("publish failed after live drop: %v", err)
	}

	mu.Lock()
	assert.Equal(t, 2, len(conns), "one initial dial plus exactly one reconnect")
	mu.Unlock()
}
