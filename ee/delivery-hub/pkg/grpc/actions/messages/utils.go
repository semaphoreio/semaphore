package messages

import (
	"github.com/renderedtext/go-tackle"
	config "github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/reflect/protoreflect"
)

const DeliveryHubCanvasExchange = "delivery-hub.canvas-exchange"

func Publish(exchange string, routingKey string, message []byte) error {
	amqpURL, err := config.RabbitMQURL()

	if err != nil {
		return err
	}

	return tackle.PublishMessage(&tackle.PublishParams{
		Body:       message,
		AmqpURL:    amqpURL,
		RoutingKey: routingKey,
		Exchange:   exchange,
	})
}

func toBytes(m protoreflect.ProtoMessage) []byte {
	body, err := proto.Marshal(m)
	if err != nil {
		return nil
	}
	return body
}
