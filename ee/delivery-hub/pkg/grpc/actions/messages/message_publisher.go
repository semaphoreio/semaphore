package messages

import (
	"encoding/json"

	"github.com/renderedtext/go-tackle"
	config "github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
)

const DeliveryHubExchange = "deliveryhub"

func Publish(message []byte, routingKey string) error {
	amqpURL, err := config.RabbitMQURL()

	if err != nil {
		return err
	}

	return tackle.PublishMessage(&tackle.PublishParams{
		Body:       message,
		AmqpURL:    amqpURL,
		RoutingKey: routingKey,
		Exchange:   DeliveryHubExchange,
	})
}

func toJSON(m interface{}) []byte {
	body, err := json.Marshal(m)
	if err != nil {
		return nil
	}
	return body
}
