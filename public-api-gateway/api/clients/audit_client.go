package clients

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/golang/glog"
	"github.com/renderedtext/go-tackle"
	"google.golang.org/protobuf/proto"

	auditProto "github.com/semaphoreio/semaphore/public-api-gateway/protos/audit"
)

// AuditClient provides methods for sending audit events
type AuditClient struct {
	tacklePublisher *tackle.Publisher
	amqpURL         string
}

// AuditEventOptions contains options for creating an audit event
type AuditEventOptions struct {
	// UserID of the user performing the action
	UserID string
	// OrgID of the organization where the action is performed
	OrgID string
	// Resource type that is being audited
	Resource auditProto.Event_Resource
	// Operation being performed
	Operation auditProto.Event_Operation
	// Description of the audit event
	Description string
	// ResourceID of the affected resource
	ResourceID string
	// ResourceName of the affected resource
	ResourceName string
	// Medium through which the action was performed (e.g. API, CLI)
	Medium auditProto.Event_Medium
	// Additional metadata
	Metadata map[string]string
	// IP address of the client
	IPAddress string
	// Username of the user
	Username string
}

// NewAuditClient creates a new audit client
func NewAuditClient(amqpURL string) (*AuditClient, error) {
	client := &AuditClient{
		amqpURL: amqpURL,
	}

	if amqpURL == "" {
		return nil, fmt.Errorf("AMQP URL is required")
	}

	tacklePublisher, err := tackle.NewPublisher(amqpURL, tackle.PublisherOptions{
		ConnectionName:    clientConnectionName(),
		ConnectionTimeout: 5 * time.Second,
	})

	if err != nil {
		return nil, fmt.Errorf("failed to create AMQP publisher: %w", err)
	}

	client.tacklePublisher = tacklePublisher

	return client, nil
}

// SendAuditEvent sends an audit event via AMQP
func (c *AuditClient) SendAuditEvent(ctx context.Context, event *auditProto.Event) error {
	data, err := proto.Marshal(event)
	if err != nil {
		return fmt.Errorf("error marshaling audit event: %w", err)
	}

	err = c.tacklePublisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       data,
		Exchange:   "audit",
		RoutingKey: "log",
	})

	if err != nil {
		glog.Errorf("Error publishing audit event: %v", err)
		return fmt.Errorf("error publishing audit event: %w", err)
	}

	glog.Infof("Audit event published via AMQP: resource=%s, operation=%s, resource_id=%s, operation_id=%s", event.Resource.String(), event.Operation.String(), event.ResourceId, event.OperationId)

	return nil
}

func clientConnectionName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "public-api-gateway"
	}

	return hostname
}
