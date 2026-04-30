package audit

import (
	"context"
	"errors"
	"net/http"
	"sync"
	"testing"

	auditpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/audit"
)

type publisherSpy struct {
	mu     sync.Mutex
	events []*auditpb.Event
	err    error
}

func (p *publisherSpy) Publish(_ context.Context, event *auditpb.Event) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.events = append(p.events, event)
	return p.err
}

func (p *publisherSpy) count() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.events)
}

func TestConfigureFromEnvReturnsNilWhenAuditLoggingIsDisabled(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "false")
	t.Setenv("AMQP_URL", "")

	restore := SetPublisherForTests(nil)
	defer restore()

	cleanup, err := ConfigureFromEnv()
	if err != nil {
		t.Fatalf("expected no error when audit logging is disabled, got %v", err)
	}
	cleanup()
}

func TestConfigureFromEnvFailsWhenAMQPURLIsMissing(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", "")

	restore := SetPublisherForTests(nil)
	defer restore()

	_, err := ConfigureFromEnv()
	if err == nil {
		t.Fatal("expected error when audit logging is enabled and AMQP_URL is missing")
	}
}

func TestConfigureFromEnvDoesNotEagerlyInitializePublisher(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", "amqp://test")

	restore := SetPublisherForTests(nil)
	defer restore()

	initCalls := 0
	prevFactory := newPublisherFactory
	newPublisherFactory = func(_ string) (EventPublisher, error) {
		initCalls++
		return &publisherSpy{}, nil
	}
	t.Cleanup(func() {
		newPublisherFactory = prevFactory
	})

	cleanup, err := ConfigureFromEnv()
	if err != nil {
		t.Fatalf("expected successful configure, got %v", err)
	}
	defer cleanup()

	if initCalls != 0 {
		t.Fatalf("expected no eager publisher init during configure, got %d init calls", initCalls)
	}
}

func TestAuditedOperationInitializesPublisherOnFirstPublish(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", "amqp://test")

	restore := SetPublisherForTests(nil)
	defer restore()

	spy := &publisherSpy{}
	initCalls := 0
	prevFactory := newPublisherFactory
	newPublisherFactory = func(_ string) (EventPublisher, error) {
		initCalls++
		return spy, nil
	}
	t.Cleanup(func() {
		newPublisherFactory = prevFactory
	})

	cleanup, err := ConfigureFromEnv()
	if err != nil {
		t.Fatalf("expected successful configure, got %v", err)
	}
	defer cleanup()

	err = LogArtifactDownload(context.Background(), http.Header{}, ArtifactDownloadParams{
		UserID:       "77777777-7777-7777-7777-777777777777",
		OrgID:        "11111111-1111-1111-1111-111111111111",
		ResourceName: "artifacts/jobs/55555555-5555-5555-5555-555555555555/agent/job_logs.txt",
		SourceKind:   "jobs",
		SourceID:     "55555555-5555-5555-5555-555555555555",
		ProjectID:    "33333333-3333-3333-3333-333333333333",
		Method:       "GET",
		AuditEnabled: true,
	})
	if err != nil {
		t.Fatalf("expected audited publish to succeed, got %v", err)
	}

	if initCalls != 1 {
		t.Fatalf("expected single lazy init call, got %d", initCalls)
	}
	if spy.count() != 1 {
		t.Fatalf("expected one published event, got %d", spy.count())
	}
}

func TestAuditedOperationFailsWhenPublisherInitFails(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", "amqp://test")

	restore := SetPublisherForTests(nil)
	defer restore()

	prevFactory := newPublisherFactory
	newPublisherFactory = func(_ string) (EventPublisher, error) {
		return nil, errors.New("dial failed")
	}
	t.Cleanup(func() {
		newPublisherFactory = prevFactory
	})

	cleanup, err := ConfigureFromEnv()
	if err != nil {
		t.Fatalf("expected successful configure, got %v", err)
	}
	defer cleanup()

	err = LogArtifactDownload(context.Background(), http.Header{}, ArtifactDownloadParams{
		UserID:       "77777777-7777-7777-7777-777777777777",
		OrgID:        "11111111-1111-1111-1111-111111111111",
		ResourceName: "artifacts/jobs/55555555-5555-5555-5555-555555555555/agent/job_logs.txt",
		SourceKind:   "jobs",
		SourceID:     "55555555-5555-5555-5555-555555555555",
		ProjectID:    "33333333-3333-3333-3333-333333333333",
		Method:       "GET",
		AuditEnabled: true,
	})
	if err == nil {
		t.Fatal("expected audited operation to fail when publisher init fails")
	}
}

func TestAuditedOperationRetriesPublisherInitAfterFailure(t *testing.T) {
	t.Setenv("AUDIT_LOGGING", "true")
	t.Setenv("AMQP_URL", "amqp://test")

	restore := SetPublisherForTests(nil)
	defer restore()

	spy := &publisherSpy{}
	initCalls := 0
	prevFactory := newPublisherFactory
	newPublisherFactory = func(_ string) (EventPublisher, error) {
		initCalls++
		if initCalls == 1 {
			return nil, errors.New("first dial failed")
		}
		return spy, nil
	}
	t.Cleanup(func() {
		newPublisherFactory = prevFactory
	})

	cleanup, err := ConfigureFromEnv()
	if err != nil {
		t.Fatalf("expected successful configure, got %v", err)
	}
	defer cleanup()

	firstErr := LogArtifactDownload(context.Background(), http.Header{}, ArtifactDownloadParams{
		UserID:       "77777777-7777-7777-7777-777777777777",
		OrgID:        "11111111-1111-1111-1111-111111111111",
		ResourceName: "artifacts/jobs/55555555-5555-5555-5555-555555555555/agent/job_logs.txt",
		SourceKind:   "jobs",
		SourceID:     "55555555-5555-5555-5555-555555555555",
		ProjectID:    "33333333-3333-3333-3333-333333333333",
		Method:       "GET",
		AuditEnabled: true,
	})
	if firstErr == nil {
		t.Fatal("expected first audited operation to fail when initial init fails")
	}

	secondErr := LogArtifactDownload(context.Background(), http.Header{}, ArtifactDownloadParams{
		UserID:       "77777777-7777-7777-7777-777777777777",
		OrgID:        "11111111-1111-1111-1111-111111111111",
		ResourceName: "artifacts/jobs/55555555-5555-5555-5555-555555555555/agent/job_logs.txt",
		SourceKind:   "jobs",
		SourceID:     "55555555-5555-5555-5555-555555555555",
		ProjectID:    "33333333-3333-3333-3333-333333333333",
		Method:       "GET",
		AuditEnabled: true,
	})
	if secondErr != nil {
		t.Fatalf("expected second audited operation to recover after re-init, got %v", secondErr)
	}

	if initCalls != 2 {
		t.Fatalf("expected two init attempts, got %d", initCalls)
	}
	if spy.count() != 1 {
		t.Fatalf("expected one successful published event, got %d", spy.count())
	}
}
