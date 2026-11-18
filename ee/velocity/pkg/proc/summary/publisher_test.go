package summary

import (
	"os"
	"sync"
	"sync/atomic"
	"testing"

	rabbit "github.com/rabbitmq/amqp091-go"
	"github.com/renderedtext/go-tackle"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func testSummaryOptions() tackle.Options {
	return tackle.Options{
		URL:            os.Getenv("RABBITMQ_URL"),
		ConnectionName: "velocity.summary_processor.test",
		RemoteExchange: "velocity_summary_test_exchange",
		RoutingKey:     "done",
	}
}

func testPublishParams(options tackle.Options) *tackle.PublishParams {
	return &tackle.PublishParams{
		Body:       []byte("summary event"),
		AmqpURL:    options.URL,
		RoutingKey: options.RoutingKey,
		Exchange:   options.RemoteExchange,
	}
}

func requireBroker(t *testing.T) {
	if os.Getenv("RABBITMQ_URL") == "" {
		t.Skip("RABBITMQ_URL not set; skipping broker integration test")
	}
}

func TestOpenPublisherDeclaresExchangeAndPublishes(t *testing.T) {
	requireBroker(t)

	options := testSummaryOptions()

	publisher, err := openPublisher(options)
	require.NoError(t, err)
	defer publisher.Close()

	require.NoError(t, publish(publisher, testPublishParams(options)))
}

func TestPublisherIsSharedAcrossDeliveries(t *testing.T) {
	requireBroker(t)

	options := testSummaryOptions()

	var dials int32

	publisher, err := tackle.NewPublisher(options.URL, tackle.PublisherOptions{
		ConnectionName:    options.ConnectionName,
		ConnectionTimeout: publisherConnectionTimeout,
		ConnectFunc: func() (*rabbit.Connection, error) {
			atomic.AddInt32(&dials, 1)
			return rabbit.Dial(options.URL)
		},
	})
	require.NoError(t, err)
	defer publisher.Close()
	require.NoError(t, publisher.ExchangeDeclare(options.RemoteExchange))

	wg := new(sync.WaitGroup)
	errs := make(chan error, 100)

	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := publish(publisher, testPublishParams(options)); err != nil {
				errs <- err
			}
		}()
	}

	wg.Wait()
	close(errs)

	for err := range errs {
		t.Errorf("publish failed: %v", err)
	}

	assert.Equal(t, int32(1), atomic.LoadInt32(&dials), "100 deliveries must share one AMQP connection")
}
