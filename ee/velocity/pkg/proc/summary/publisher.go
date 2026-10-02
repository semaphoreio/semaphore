package summary

import (
	"context"
	"time"

	"github.com/renderedtext/go-tackle"
)

const (
	publisherConnectionTimeout = 5 * time.Second
	publishTimeout             = 15 * time.Second
)

func openPublisher(options tackle.Options) (*tackle.Publisher, error) {
	publisher, err := tackle.NewPublisher(options.URL, tackle.PublisherOptions{
		ConnectionName:    options.ConnectionName,
		ConnectionTimeout: publisherConnectionTimeout,
	})
	if err != nil {
		return nil, err
	}

	if err := publisher.ExchangeDeclare(options.RemoteExchange); err != nil {
		publisher.Close()
		return nil, err
	}

	return publisher, nil
}

func publish(publisher *tackle.Publisher, params *tackle.PublishParams) error {
	ctx, cancel := context.WithTimeout(context.Background(), publishTimeout)
	defer cancel()

	return publisher.PublishWithContext(ctx, params)
}
