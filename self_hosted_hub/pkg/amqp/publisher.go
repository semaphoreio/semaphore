package amqp

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/uuid"

	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/logging"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	auditProto "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/audit"
	jobStateProto "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.mq.job_state_exchange"
	log "github.com/sirupsen/logrus"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type Publisher struct {
	URL             string
	tacklePublisher *tackle.Publisher
}

func NewPublisher(URL string) (*Publisher, error) {
	tacklePublisher, err := tackle.NewPublisher(URL, tackle.PublisherOptions{
		ConnectionName:    clientConnectionName(),
		ConnectionTimeout: 5 * time.Second,
	})

	if err != nil {
		return nil, err
	}

	return &Publisher{URL: URL, tacklePublisher: tacklePublisher}, nil
}

/*
 * Zebra needs to know about the job finishing and its result.
 * We send that information in a RabbitMQ message,
 * directed at the 'job_callbacks' exchange, with a 'finished' routing key.
 * For old agents (agents that used the callback broker to deliver this information),
 * this information was delivered directly to Zebra, and not from a job-finished sync.
 */
func (p *Publisher) PublishFinishedCallback(ctx context.Context, jobID, result string) error {
	jobFinishedMessage, err := buildJobFinishedMessage(jobID, result)
	if err != nil {
		return err
	}

	log.Infof("Publishing finished message for %s", jobID)
	return p.tacklePublisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       jobFinishedMessage,
		Exchange:   "job_callbacks",
		RoutingKey: "finished",
	})
}

func (p *Publisher) PublishStartedCallback(ctx context.Context, jobID string, agent *models.Agent) error {
	jobStartedMessage, err := buildJobStartedMessage(jobID, agent)
	if err != nil {
		return err
	}

	log.Infof("Publishing job_started message for %s", jobID)
	return p.tacklePublisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       jobStartedMessage,
		Exchange:   "server_farm.job_state_exchange",
		RoutingKey: "job_started",
	})
}

/*
 * Loghub2 needs to know when it is supposed to wrap up
 * all the logs from Redis, and send them to the final storage bucket.
 * The teardown_finished callback is what accomplishes that.
 * For old agents, that callback is sent by Zebra,
 * when Zebra receives the teardown_finished callback from the agent.
 * Note that this message goes to a different exchange, and not the same one used for the `finished` event.
 * This one is directed at the 'server_farm.job_state_exchange' exchange, with a 'job_teardown_finished' routing key.
 */
func (p *Publisher) PublishTeardownFinishedCallback(ctx context.Context, jobID string) error {
	jobTeardownFinishedMessage, err := buildJobTeardownFinishedMessage(jobID)
	if err != nil {
		return err
	}

	log.Infof("Publishing teardown_finished message for %s", jobID)
	return p.tacklePublisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       jobTeardownFinishedMessage,
		Exchange:   "server_farm.job_state_exchange",
		RoutingKey: "job_teardown_finished",
	})
}

func (p *Publisher) HandleJobFinished(ctx context.Context, jobID string, result string) error {
	err := p.PublishFinishedCallback(ctx, jobID, result)
	if err != nil {
		return err
	}

	err = p.PublishTeardownFinishedCallback(ctx, jobID)
	if err != nil {
		return err
	}

	return nil
}

func buildJobFinishedMessage(jobId, result string) ([]byte, error) {

	/*
	 * Zebra expects a message like: {payload: '{"result":"passed"}', job_hash_id: 'job-123'}.
	 * Note the payload field isn't an object, but a string. So, we need to follow that here.
	 */
	payload, err := json.Marshal(map[string]string{"result": result})
	if err != nil {
		return nil, err
	}

	data, err := json.Marshal(map[string]interface{}{
		"job_hash_id": jobId,
		"payload":     string(payload),
	})

	if err != nil {
		return nil, err
	}

	return data, nil
}

func buildJobStartedMessage(jobId string, agent *models.Agent) ([]byte, error) {
	jobStarted := &jobStateProto.JobStarted{
		JobId:     jobId,
		Timestamp: timestamppb.Now(),
		AgentId:   agent.ID.String(),
		AgentName: agent.Name,
	}

	data, err := proto.Marshal(jobStarted)
	if err != nil {
		return nil, err
	}

	return data, nil
}

func buildJobTeardownFinishedMessage(jobId string) ([]byte, error) {
	jobFinished := &jobStateProto.JobFinished{
		JobId:      jobId,
		SelfHosted: true,
		Timestamp:  timestamppb.Now(),
	}

	data, err := proto.Marshal(jobFinished)
	if err != nil {
		return nil, err
	}

	return data, nil
}

type AuditLogOptions struct {
	UserID      *uuid.UUID
	Operation   auditProto.Event_Operation
	Description string
}

func buildAuditLog(agent *models.Agent, options AuditLogOptions) ([]byte, error) {
	opID, err := uuid.NewRandom()
	if err != nil {
		return nil, fmt.Errorf("error generating operation ID: %v", err)
	}

	metadataMap := map[string]string{
		"agent_type_name": agent.AgentTypeName,
		"ip_address":      agent.IPAddress,
		"architecture":    agent.Arch,
		"hostname":        agent.Hostname,
		"os":              agent.OS,
		"version":         agent.Version,
	}

	metadata, err := json.Marshal(metadataMap)
	if err != nil {
		return nil, fmt.Errorf("error marshaling metadata: %v", err)
	}

	event := &auditProto.Event{
		UserId:       options.UserID.String(),
		OrgId:        agent.OrganizationID.String(),
		Resource:     auditProto.Event_SelfHostedAgent,
		ResourceName: agent.Name,
		Operation:    options.Operation,
		OperationId:  opID.String(),
		Description:  options.Description,
		Timestamp:    timestamppb.Now(),
		Medium:       auditProto.Event_API,
		Metadata:     string(metadata),
	}

	data, err := proto.Marshal(event)
	if err != nil {
		return nil, err
	}

	return data, nil
}

func (p *Publisher) PublishAuditLogEvent(ctx context.Context, agent *models.Agent, options AuditLogOptions) error {
	if options.UserID == nil {
		logging.ForAgent(agent).Warn("No user ID - not sending audit log")
		return nil
	}

	auditLog, err := buildAuditLog(agent, options)
	if err != nil {
		logging.ForAgent(agent).Errorf("Error building audit log: %v", err)
		return err
	}

	return p.tacklePublisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       auditLog,
		Exchange:   "audit",
		RoutingKey: "log",
	})
}

func clientConnectionName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "self_hosted_hub"
	}

	return hostname
}
