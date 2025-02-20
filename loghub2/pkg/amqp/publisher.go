package amqp

import (
	"context"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
)

func PublishMessage(ctx context.Context, amqpURL string, queueName string, body []byte, headers amqp.Table) error {
	config := amqp.Config{Properties: amqp.NewConnectionProperties()}
	config.Properties.SetClientConnectionName(utils.ClientConnectionName())

	connection, err := amqp.DialConfig(amqpURL, config)
	if err != nil {
		return err
	}

	defer connection.Close()

	channel, err := connection.Channel()
	if err != nil {
		return err
	}

	defer channel.Close()

	err = channel.PublishWithContext(ctx, "", queueName, false, false, amqp.Publishing{
		Body:    body,
		Headers: headers,
	})

	if err != nil {
		return err
	}

	return nil
}
