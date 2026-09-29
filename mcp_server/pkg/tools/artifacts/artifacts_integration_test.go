//go:build integration

package artifacts

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	auditlog "github.com/semaphoreio/semaphore/mcp_server/pkg/audit"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	auditpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/audit"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"
	"google.golang.org/protobuf/proto"
)

const (
	auditExchangeName = "audit"
	auditRoutingKey   = "log"
)

func TestArtifactsSignedURLPublishesAuditEventToRabbitMQ(t *testing.T) {
	amqpURL := strings.TrimSpace(os.Getenv("AMQP_URL"))
	if amqpURL == "" {
		t.Skip("AMQP_URL is not set")
	}

	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", amqpURL)
	auditCleanup, err := auditlog.ConfigureFromEnv()
	if err != nil {
		t.Fatalf("configure audit publisher: %v", err)
	}
	defer auditCleanup()

	conn, err := amqp.Dial(amqpURL)
	if err != nil {
		t.Fatalf("dial AMQP: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		t.Fatalf("open AMQP channel: %v", err)
	}
	defer ch.Close()

	if err := ch.ExchangeDeclare(auditExchangeName, "direct", true, false, false, false, nil); err != nil {
		t.Fatalf("declare audit exchange: %v", err)
	}

	queue, err := ch.QueueDeclare("", false, true, true, false, nil)
	if err != nil {
		t.Fatalf("declare test queue: %v", err)
	}

	if err := ch.QueueBind(queue.Name, auditRoutingKey, auditExchangeName, false, nil); err != nil {
		t.Fatalf("bind test queue: %v", err)
	}

	artifactClient := &artifacthubClientStub{
		signedURL: "https://example.com/job-signed",
	}
	provider := &support.MockProvider{
		Timeout:           time.Second,
		JobClient:         &jobClientStub{orgID: testOrgID, projectID: testProjectID},
		ArtifacthubClient: artifactClient,
		ProjectClient: &support.ProjectClientStub{
			Response: newProjectDescribeResponse(testOrgID, testProjectID, testArtifactStore),
		},
		RBACClient: support.NewRBACStub(artifactsRequiredPermissions...),
		FeaturesService: support.FeatureClientStub{
			State: feature.Hidden,
			States: map[string]feature.State{
				"mcp_server_read_tools":      feature.Enabled,
				"mcp_server_artifacts_tools": feature.Enabled,
				"audit_logs":                 feature.Enabled,
			},
		},
	}

	req := callRequest(map[string]any{
		"organization_id": testOrgID,
		"scope":           scopeJobs,
		"scope_id":        testJobID,
		"path":            "agent/output.log",
		"method":          "GET",
	}, true)
	req.Header.Set("X-Request-Id", "req-int-signed-url-001")
	req.Header.Set("X-Forwarded-For", "198.51.100.42, 10.0.0.4")
	req.Header.Set("User-Agent", "SemaphoreCLI/1.0")

	res, err := signedURLHandler(provider)(context.Background(), req)
	if err != nil {
		t.Fatalf("handler error: %v", err)
	}
	if res == nil || res.IsError {
		t.Fatalf("expected successful response, got: %#v", res)
	}

	event := receiveAuditEvent(t, ch, queue.Name)
	if event.GetResource() != auditpb.Event_Artifact {
		t.Fatalf("expected resource Artifact, got %v", event.GetResource())
	}
	if event.GetOperation() != auditpb.Event_Download {
		t.Fatalf("expected operation Download, got %v", event.GetOperation())
	}
	if event.GetUserId() != testUserID {
		t.Fatalf("expected user_id %s, got %s", testUserID, event.GetUserId())
	}
	if event.GetOrgId() != testOrgID {
		t.Fatalf("expected org_id %s, got %s", testOrgID, event.GetOrgId())
	}
	if event.GetOperationId() != "req-int-signed-url-001" {
		t.Fatalf("expected operation_id req-int-signed-url-001, got %s", event.GetOperationId())
	}
	expectedResourceName := "artifacts/jobs/" + testJobID + "/agent/output.log"
	if event.GetResourceName() != expectedResourceName {
		t.Fatalf("expected resource_name %s, got %s", expectedResourceName, event.GetResourceName())
	}
	if event.GetMedium() != auditpb.Event_MCP {
		t.Fatalf("expected medium MCP, got %v", event.GetMedium())
	}

	if extra := countAdditionalEvents(t, ch, queue.Name); extra != 0 {
		t.Fatalf("expected exactly 1 audit message, got %d", 1+extra)
	}
}

func receiveAuditEvent(t *testing.T, ch *amqp.Channel, queueName string) *auditpb.Event {
	t.Helper()

	deadline := time.Now().Add(6 * time.Second)
	for time.Now().Before(deadline) {
		msg, ok, err := ch.Get(queueName, true)
		if err != nil {
			t.Fatalf("consume audit event: %v", err)
		}
		if !ok {
			time.Sleep(100 * time.Millisecond)
			continue
		}

		event := &auditpb.Event{}
		if err := proto.Unmarshal(msg.Body, event); err != nil {
			t.Fatalf("decode audit event: %v", err)
		}
		return event
	}

	t.Fatal("did not receive audit event from RabbitMQ")
	return nil
}

func countAdditionalEvents(t *testing.T, ch *amqp.Channel, queueName string) int {
	t.Helper()

	count := 0
	deadline := time.Now().Add(300 * time.Millisecond)
	for time.Now().Before(deadline) {
		msg, ok, err := ch.Get(queueName, true)
		if err != nil {
			t.Fatalf("consume extra audit event: %v", err)
		}
		if !ok {
			time.Sleep(25 * time.Millisecond)
			continue
		}
		if len(msg.Body) > 0 {
			count++
		}
	}
	return count
}
