package testconsumer

import (
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
)

const TestConsumerService = "TestConsumerService"

type TestConsumer struct {
	amqpUrl        string
	exchangeName   string
	routingKey     string
	consumer       *tackle.Consumer
	messageChannel chan bool
}

func New(amqpUrl string, exchangeName string, routingKey string) TestConsumer {
	return TestConsumer{
		amqpUrl:        amqpUrl,
		exchangeName:   exchangeName,
		routingKey:     routingKey,
		messageChannel: make(chan bool),
		consumer:       tackle.NewConsumer(),
	}
}

func (c *TestConsumer) Start() {
	randomServiceName := fmt.Sprintf("%s.%s", TestConsumerService, uuid.NewString())

	go c.consumer.Start(&tackle.Options{
		URL:            c.amqpUrl,
		RemoteExchange: c.exchangeName,
		Service:        randomServiceName,
		RoutingKey:     c.routingKey,
	}, func(d tackle.Delivery) error {
		c.messageChannel <- true
		return nil
	})

	c.waitForInitialization()
}

func (c *TestConsumer) waitForInitialization() {
	for c.consumer.State != tackle.StateListening {
		time.Sleep(100 * time.Millisecond)
	}
}

func (c *TestConsumer) Stop() {
	c.consumer.Stop()
}

func (c *TestConsumer) HasReceivedMessage() bool {
	select {
	case <-c.messageChannel:
		return true
	case <-time.After(3000 * time.Millisecond):
		return false
	}
}
