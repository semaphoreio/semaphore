package jobdeleter

import (
	"context"
	"errors"
	"testing"
)

func TestProcessMessageDeletesArtifacts(t *testing.T) {
	var (
		called      bool
		capturedCtx context.Context
	)

	worker := &Worker{
		deletePath: func(ctx context.Context, artifactID, path string) error {
			called = true
			capturedCtx = ctx

			if artifactID != "artifact-1" {
				t.Fatalf("unexpected artifact id %s", artifactID)
			}

			if path != "artifacts/jobs/job-1/" {
				t.Fatalf("unexpected path %s", path)
			}

			return nil
		},
	}

	err := worker.processMessage([]byte(`{"artifact_id":"artifact-1","job_id":"job-1"}`))

	if err != nil {
		t.Fatalf("unexpected error %v", err)
	}

	if !called {
		t.Fatalf("deletePath was not invoked")
	}

	if _, ok := capturedCtx.Deadline(); !ok {
		t.Fatalf("expected context with deadline")
	}
}

func TestProcessMessagePropagatesDeleteErrors(t *testing.T) {
	expectedErr := errors.New("boom")

	worker := &Worker{
		deletePath: func(ctx context.Context, artifactID, path string) error {
			return expectedErr
		},
	}

	err := worker.processMessage([]byte(`{"artifact_id":"artifact-1","job_id":"job-1"}`))

	if !errors.Is(err, expectedErr) {
		t.Fatalf("expected error %v, got %v", expectedErr, err)
	}
}

func TestProcessMessageFailsOnInvalidMessage(t *testing.T) {
	worker := &Worker{
		deletePath: func(ctx context.Context, artifactID, path string) error {
			t.Fatalf("deletePath should not be called for invalid payloads")
			return nil
		},
	}

	err := worker.processMessage([]byte(`{"artifact_id":"","job_id":""}`))
	if err == nil {
		t.Fatalf("expected error for invalid message")
	}
}
