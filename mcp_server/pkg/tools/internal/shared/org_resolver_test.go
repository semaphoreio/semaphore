package shared

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	"google.golang.org/grpc"
)

type describeStub struct {
	responses map[string]*orgpb.Organization
	calls     int
	err       error
}

func (d *describeStub) Describe(ctx context.Context, in *orgpb.DescribeRequest, opts ...grpc.CallOption) (*orgpb.DescribeResponse, error) {
	if d.err != nil {
		return nil, d.err
	}
	d.calls++
	org := d.responses[strings.ToLower(strings.TrimSpace(in.GetOrgId()))]
	if org == nil {
		return &orgpb.DescribeResponse{
			Status: &responsepb.ResponseStatus{
				Code:    responsepb.ResponseStatus_BAD_PARAM,
				Message: "not found",
			},
		}, nil
	}
	return &orgpb.DescribeResponse{
		Status: &responsepb.ResponseStatus{
			Code: responsepb.ResponseStatus_OK,
		},
		Organization: org,
	}, nil
}

func TestCachedOrgResolverCachesResults(t *testing.T) {
	stub := &describeStub{
		responses: map[string]*orgpb.Organization{
			"org-1": {OrgId: "org-1", Name: "Acme Org"},
		},
	}
	now := time.Unix(0, 0)
	resolver := &cachedOrgResolver{
		client:  stub,
		timeout: time.Second,
		ttl:     time.Minute,
		now: func() time.Time {
			return now
		},
		cache: make(map[string]orgCacheEntry),
	}

	name, err := resolver.Resolve(context.Background(), "ORG-1")
	if err != nil {
		t.Fatalf("resolve returned error: %v", err)
	}
	if name != "Acme Org" {
		t.Fatalf("expected Acme Org, got %q", name)
	}

	name, err = resolver.Resolve(context.Background(), "org-1")
	if err != nil {
		t.Fatalf("second resolve returned error: %v", err)
	}
	if name != "Acme Org" {
		t.Fatalf("expected cached Acme Org, got %q", name)
	}
	if stub.calls != 1 {
		t.Fatalf("expected single RPC, got %d", stub.calls)
	}
}

func TestCachedOrgResolverExpiresEntries(t *testing.T) {
	stub := &describeStub{
		responses: map[string]*orgpb.Organization{
			"org-2": {OrgId: "org-2", Name: "Beta Org"},
		},
	}
	now := time.Unix(0, 0)
	resolver := &cachedOrgResolver{
		client:  stub,
		timeout: time.Second,
		ttl:     30 * time.Second,
		now: func() time.Time {
			return now
		},
		cache: make(map[string]orgCacheEntry),
	}

	if _, err := resolver.Resolve(context.Background(), "org-2"); err != nil {
		t.Fatalf("resolve failed: %v", err)
	}
	if stub.calls != 1 {
		t.Fatalf("expected call count 1, got %d", stub.calls)
	}

	now = now.Add(time.Minute)
	if _, err := resolver.Resolve(context.Background(), "org-2"); err != nil {
		t.Fatalf("resolve after expiry failed: %v", err)
	}
	if stub.calls != 2 {
		t.Fatalf("expected cache miss after expiry (2 calls), got %d", stub.calls)
	}
}

func TestCachedOrgResolverPropagatesErrors(t *testing.T) {
	stub := &describeStub{err: errors.New("boom")}
	resolver := &cachedOrgResolver{
		client:  stub,
		timeout: time.Second,
		ttl:     time.Minute,
		now:     time.Now,
		cache:   make(map[string]orgCacheEntry),
	}

	if _, err := resolver.Resolve(context.Background(), "org-3"); err == nil {
		t.Fatalf("expected error")
	}
}

func TestCachedOrgResolverConcurrentAccess(t *testing.T) {
	stub := &describeStub{
		responses: map[string]*orgpb.Organization{
			"org-1": {OrgId: "org-1", Name: "Org One"},
			"org-2": {OrgId: "org-2", Name: "Org Two"},
			"org-3": {OrgId: "org-3", Name: "Org Three"},
		},
	}
	resolver := &cachedOrgResolver{
		client:  stub,
		timeout: time.Second,
		ttl:     time.Minute,
		now:     time.Now,
		cache:   make(map[string]orgCacheEntry),
	}

	// Pre-populate cache with org-1 to test cached access pattern
	_, err := resolver.Resolve(context.Background(), "org-1")
	if err != nil {
		t.Fatalf("failed to pre-populate cache: %v", err)
	}
	initialCalls := stub.calls // Should be 1

	const goroutines = 50
	const iterations = 10

	done := make(chan bool, goroutines)
	errCh := make(chan error, goroutines*iterations)

	// Launch multiple goroutines that concurrently access the resolver
	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer func() { done <- true }()
			for j := 0; j < iterations; j++ {
				// Each goroutine accesses all three orgs
				// org-1 is cached, org-2 and org-3 need to be fetched
				orgIDs := []string{"org-1", "org-2", "org-3"}
				for _, orgID := range orgIDs {
					name, err := resolver.Resolve(context.Background(), orgID)
					if err != nil {
						errCh <- err
						return
					}
					// Verify we got a valid name
					if name == "" {
						errCh <- errors.New("got empty org name")
						return
					}
				}
			}
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < goroutines; i++ {
		<-done
	}
	close(errCh)

	// Check for any errors
	for err := range errCh {
		t.Fatalf("concurrent access error: %v", err)
	}

	// Verify caching worked:
	// - org-1 was pre-cached: 0 additional calls
	// - org-2 and org-3: at most a few calls each (due to concurrent first access)
	// Total should be much less than goroutines * iterations * 2 (uncached orgs)
	totalCalls := stub.calls
	expectedMax := initialCalls + 20 // Allow some concurrent fetches for org-2 and org-3

	if totalCalls > expectedMax {
		t.Fatalf("too many RPC calls: expected at most %d, got %d (caching may not be working)", expectedMax, totalCalls)
	}

	// Verify we made at least some calls for org-2 and org-3
	if totalCalls <= initialCalls {
		t.Fatalf("expected additional calls for org-2 and org-3, got %d total (%d initial)", totalCalls, initialCalls)
	}
}
