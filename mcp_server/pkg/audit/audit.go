package audit

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	auditpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/audit"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/logging"
	"github.com/sirupsen/logrus"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const (
	auditExchangeName = "audit"
	auditRoutingKey   = "log"
)

type EventPublisher interface {
	Publish(ctx context.Context, event *auditpb.Event) error
}

type ArtifactDownloadParams struct {
	UserID       string
	OrgID        string
	OperationID  string
	ResourceName string
	SourceKind   string
	SourceID     string
	ProjectID    string
	Method       string
	AuditEnabled bool
}

type ArtifactListParams struct {
	UserID       string
	OrgID        string
	OperationID  string
	ResourceName string
	SourceKind   string
	SourceID     string
	ProjectID    string
}

type WorkflowRebuildParams struct {
	UserID       string
	OrgID        string
	OperationID  string
	WorkflowID   string
	ProjectID    string
	BranchName   string
	CommitSHA    string
	AuditEnabled bool
}

type noopPublisher struct{}

func (noopPublisher) Publish(context.Context, *auditpb.Event) error { return nil }

type tacklePublisher struct {
	publisher *tackle.Publisher
}

func (p *tacklePublisher) Publish(ctx context.Context, event *auditpb.Event) error {
	payload, err := proto.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshal audit event: %w", err)
	}

	if err := p.publisher.PublishWithContext(ctx, &tackle.PublishParams{
		Body:       payload,
		Exchange:   auditExchangeName,
		RoutingKey: auditRoutingKey,
	}); err != nil {
		return fmt.Errorf("publish audit event: %w", err)
	}

	return nil
}

func (p *tacklePublisher) Close() {
	if p == nil || p.publisher == nil {
		return
	}

	p.publisher.Close()
}

type managedPublisher struct {
	mu          sync.Mutex
	noop        bool
	amqpURL     string
	initialized bool
	publisher   EventPublisher
}

func newManagedPublisher(noop bool, amqpURL string) *managedPublisher {
	return &managedPublisher{
		noop:    noop,
		amqpURL: strings.TrimSpace(amqpURL),
	}
}

func (p *managedPublisher) Publish(ctx context.Context, event *auditpb.Event) error {
	if p == nil || p.noop {
		return nil
	}

	pub, err := p.getOrInitPublisher()
	if err != nil {
		return err
	}

	if err := pub.Publish(ctx, event); err != nil {
		p.resetPublisher(pub)
		return err
	}

	return nil
}

func (p *managedPublisher) Close() {
	if p == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if p.publisher != nil {
		closePublisher(p.publisher)
	}

	p.publisher = nil
	p.initialized = false
}

func (p *managedPublisher) getOrInitPublisher() (EventPublisher, error) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.publisher != nil && p.initialized {
		return p.publisher, nil
	}

	pub, err := newPublisherFactory(p.amqpURL)
	if err != nil {
		return nil, fmt.Errorf("initialize audit publisher: %w", err)
	}

	p.publisher = pub
	p.initialized = true

	return pub, nil
}

func (p *managedPublisher) resetPublisher(current EventPublisher) {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.publisher == nil || p.publisher != current {
		return
	}

	closePublisher(p.publisher)
	p.publisher = nil
	p.initialized = false
}

var (
	publisherMu         sync.RWMutex
	currentPublisher    EventPublisher = noopPublisher{}
	newPublisherFactory                = newTacklePublisher
)

func ConfigureFromEnv() (func(), error) {
	logger := logging.ForComponent("audit")

	if !auditLoggingEnabled(logger) {
		pub := newManagedPublisher(true, "")
		setPublisher(pub)
		logger.Info("audit logging disabled via AUDIT_LOGGING")
		return pub.Close, nil
	}

	amqpURL := strings.TrimSpace(os.Getenv("AMQP_URL"))
	if amqpURL == "" {
		return noOpCleanup, fmt.Errorf("audit logging is enabled but AMQP_URL is not set")
	}

	pub := newManagedPublisher(false, amqpURL)
	setPublisher(pub)
	logger.Info("audit logging enabled")
	return pub.Close, nil
}

func LogArtifactDownload(ctx context.Context, headers http.Header, params ArtifactDownloadParams) error {
	if ctx == nil {
		ctx = context.Background()
	}

	metadataJSON, err := json.Marshal(map[string]string{
		"source_kind":    strings.TrimSpace(params.SourceKind),
		"source_id":      strings.TrimSpace(params.SourceID),
		"project_id":     strings.TrimSpace(params.ProjectID),
		"request_method": strings.TrimSpace(params.Method),
	})
	if err != nil {
		logging.ForComponent("audit").WithError(err).Error("failed to marshal audit metadata")
		metadataJSON = []byte("{}")
	}

	event := &auditpb.Event{
		Resource:     auditpb.Event_Artifact,
		Operation:    auditpb.Event_Download,
		UserId:       strings.TrimSpace(params.UserID),
		OrgId:        strings.TrimSpace(params.OrgID),
		IpAddress:    detectRemoteAddress(headers),
		Username:     "",
		Description:  "",
		Metadata:     string(metadataJSON),
		Timestamp:    timestamppb.Now(),
		OperationId:  resolveOperationID(headers, params.OperationID),
		ResourceId:   strings.TrimSpace(params.SourceID),
		ResourceName: strings.TrimSpace(params.ResourceName),
		Medium:       auditpb.Event_MCP,
	}

	logArtifactOperation(event)

	if !params.AuditEnabled {
		return nil
	}

	if err := getPublisher().Publish(ctx, event); err != nil {
		logging.ForComponent("audit").
			WithError(err).
			WithField("resourceName", event.GetResourceName()).
			WithField("operationId", event.GetOperationId()).
			Error("failed to publish audit event")

		return err
	}

	return nil
}

func LogWorkflowRebuild(ctx context.Context, headers http.Header, params WorkflowRebuildParams) error {
	if ctx == nil {
		ctx = context.Background()
	}

	metadataJSON, err := json.Marshal(map[string]string{
		"project_id":  strings.TrimSpace(params.ProjectID),
		"branch_name": strings.TrimSpace(params.BranchName),
		"workflow_id": strings.TrimSpace(params.WorkflowID),
		"commit_sha":  strings.TrimSpace(params.CommitSHA),
	})
	if err != nil {
		logging.ForComponent("audit").WithError(err).Error("failed to marshal audit metadata")
		metadataJSON = []byte("{}")
	}

	event := &auditpb.Event{
		Resource:     auditpb.Event_Workflow,
		Operation:    auditpb.Event_Rebuild,
		UserId:       strings.TrimSpace(params.UserID),
		OrgId:        strings.TrimSpace(params.OrgID),
		IpAddress:    detectRemoteAddress(headers),
		Username:     "",
		Description:  "Rebuilt the workflow",
		Metadata:     string(metadataJSON),
		Timestamp:    timestamppb.Now(),
		OperationId:  resolveOperationID(headers, params.OperationID),
		ResourceId:   "",
		ResourceName: strings.TrimSpace(params.WorkflowID),
		Medium:       auditpb.Event_MCP,
	}

	logWorkflowOperation(event)

	if !params.AuditEnabled {
		return nil
	}

	if err := getPublisher().Publish(ctx, event); err != nil {
		logging.ForComponent("audit").
			WithError(err).
			WithField("resourceName", event.GetResourceName()).
			WithField("operationId", event.GetOperationId()).
			Error("failed to publish audit event")

		return err
	}

	return nil
}

func LogArtifactList(headers http.Header, params ArtifactListParams) {
	logging.ForComponent("audit").WithFields(logrus.Fields{
		"type":          "AuditLog",
		"event":         "artifact_operation",
		"user_id":       strings.TrimSpace(params.UserID),
		"org_id":        strings.TrimSpace(params.OrgID),
		"operation_id":  resolveOperationID(headers, params.OperationID),
		"resource":      auditpb.Event_Artifact.String(),
		"operation":     "List",
		"resource_name": strings.TrimSpace(params.ResourceName),
		"medium":        auditpb.Event_MCP.String(),
		"source_kind":   strings.TrimSpace(params.SourceKind),
		"source_id":     strings.TrimSpace(params.SourceID),
		"project_id":    strings.TrimSpace(params.ProjectID),
	}).Info("artifact audit operation")
}

func logArtifactOperation(event *auditpb.Event) {
	logOperation("artifact_operation", event)
}

func logWorkflowOperation(event *auditpb.Event) {
	logOperation("workflow_operation", event)
}

func logOperation(eventName string, event *auditpb.Event) {
	logging.ForComponent("audit").WithFields(logrus.Fields{
		"type":          "AuditLog",
		"event":         eventName,
		"user_id":       event.GetUserId(),
		"org_id":        event.GetOrgId(),
		"operation_id":  event.GetOperationId(),
		"resource":      event.GetResource().String(),
		"operation":     event.GetOperation().String(),
		"resource_name": event.GetResourceName(),
		"medium":        event.GetMedium().String(),
	}).Info("audit operation")
}

func SetPublisherForTests(publisher EventPublisher) func() {
	if publisher == nil {
		publisher = noopPublisher{}
	}

	publisherMu.Lock()
	previous := currentPublisher
	currentPublisher = publisher
	publisherMu.Unlock()

	return func() {
		publisherMu.Lock()
		currentPublisher = previous
		publisherMu.Unlock()
	}
}

func newTacklePublisher(amqpURL string) (EventPublisher, error) {
	pub, err := tackle.NewPublisher(amqpURL, tackle.PublisherOptions{
		ConnectionName:    connectionName(),
		ConnectionTimeout: 5 * time.Second,
	})
	if err != nil {
		return nil, err
	}
	return &tacklePublisher{publisher: pub}, nil
}

func connectionName() string {
	hostname := strings.TrimSpace(os.Getenv("HOSTNAME"))
	if hostname == "" {
		return "mcp_server"
	}
	return hostname
}

func auditLoggingEnabled(logger *logrus.Entry) bool {
	raw := strings.TrimSpace(os.Getenv("AUDIT_LOGGING"))
	if raw == "" {
		return true
	}

	enabled, err := strconv.ParseBool(raw)
	if err != nil {
		logger.WithField("value", raw).Warn("invalid AUDIT_LOGGING value; defaulting to enabled")
		return true
	}
	return enabled
}

func resolveOperationID(headers http.Header, explicit string) string {
	if id := strings.TrimSpace(explicit); id != "" {
		return id
	}

	if id := strings.TrimSpace(headers.Get("X-Request-Id")); id != "" {
		return id
	}

	return uuid.NewString()
}

func detectRemoteAddress(headers http.Header) string {
	if xff := strings.TrimSpace(headers.Get("X-Forwarded-For")); xff != "" {
		parts := strings.Split(xff, ",")
		if len(parts) > 0 {
			return strings.TrimSpace(parts[0])
		}
	}

	return strings.TrimSpace(headers.Get("X-Real-Ip"))
}

func setPublisher(publisher EventPublisher) {
	if publisher == nil {
		publisher = noopPublisher{}
	}
	publisherMu.Lock()
	currentPublisher = publisher
	publisherMu.Unlock()
}

func getPublisher() EventPublisher {
	publisherMu.RLock()
	defer publisherMu.RUnlock()
	return currentPublisher
}

func noOpCleanup() {}

func closePublisher(publisher EventPublisher) {
	closer, ok := publisher.(interface{ Close() })
	if !ok {
		return
	}

	closer.Close()
}
