package organizations

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	rbacpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/rbac"
	support "github.com/semaphoreio/semaphore/mcp_server/test/support"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListOrganizationsSummary(t *testing.T) {
	orgStub := &organizationClientStub{
		organizations: []*orgpb.Organization{
			{
				OrgId:       "org-1",
				Name:        "Example Org",
				OrgUsername: "example",
				CreatedAt:   timestamppb.New(time.Unix(1_700_000_000, 0)),
				Verified:    true,
			},
		},
	}
	rbacStub := &rbacClientStub{ids: []string{"org-1"}}

	provider := &support.MockProvider{
		OrganizationClient: orgStub,
		RBACClient:         rbacStub,
		Timeout:            time.Second,
	}

	res, err := listHandler(provider)(context.Background(), mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{"limit": 5},
		},
		Header: func() http.Header {
			h := http.Header{}
			h.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
			return h
		}(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.IsError {
		t.Fatalf("expected success, got error result: %+v", res)
	}

	got := res.StructuredContent.(listResult)
	if len(got.Organizations) != 1 {
		t.Fatalf("expected 1 organization, got %d", len(got.Organizations))
	}
	if got.NextCursor != "" {
		t.Fatalf("expected empty next cursor, got %q", got.NextCursor)
	}
	if got.Organizations[0].Name != "Example Org" {
		t.Fatalf("unexpected organization name: %q", got.Organizations[0].Name)
	}
	if got.Organizations[0].Details != nil {
		t.Fatalf("expected summary mode to omit details")
	}
}

func TestListOrganizationsDetailed(t *testing.T) {
	orgStub := &organizationClientStub{
		organizations: []*orgpb.Organization{
			{
				OrgId:                  "org-1",
				Name:                   "Detailed Org",
				OrgUsername:            "detail",
				AllowedIdProviders:     []string{"github"},
				IpAllowList:            []string{"1.1.1.1/32"},
				DenyMemberWorkflows:    true,
				DenyNonMemberWorkflows: true,
				Settings: []*orgpb.OrganizationSetting{
					{Key: "feature", Value: "enabled"},
				},
			},
		},
	}
	rbacStub := &rbacClientStub{ids: []string{"org-1"}}

	provider := &support.MockProvider{
		OrganizationClient: orgStub,
		RBACClient:         rbacStub,
		Timeout:            time.Second,
	}

	res, err := listHandler(provider)(context.Background(), mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"mode": "detailed",
			},
		},
		Header: func() http.Header {
			h := http.Header{}
			h.Set("X-Semaphore-User-ID", "99999999-aaaa-bbbb-cccc-dddddddddddd")
			return h
		}(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if res.IsError {
		t.Fatalf("expected success, got error result: %+v", res)
	}

	got := res.StructuredContent.(listResult)
	if len(got.Organizations) != 1 {
		t.Fatalf("unexpected organization count: %d", len(got.Organizations))
	}

	details := got.Organizations[0].Details
	if details == nil {
		t.Fatalf("expected details in detailed mode")
	}
	if len(details.AllowedIDProviders) != 1 || details.AllowedIDProviders[0] != "github" {
		t.Fatalf("unexpected allowed ID providers: %+v", details.AllowedIDProviders)
	}
	if got.Organizations[0].RawSettings["feature"] != "enabled" {
		t.Fatalf("expected settings map to include feature")
	}
}

func TestListOrganizationsPagination(t *testing.T) {
	orgStub := &organizationClientStub{
		organizations: []*orgpb.Organization{
			{OrgId: "org-2", Name: "Beta Org", OrgUsername: "beta"},
			{OrgId: "org-1", Name: "Alpha Org", OrgUsername: "alpha"},
			{OrgId: "org-3", Name: "Gamma Org", OrgUsername: "gamma"},
		},
	}
	rbacStub := &rbacClientStub{ids: []string{"org-1", "org-2", "org-3"}}
	provider := &support.MockProvider{
		OrganizationClient: orgStub,
		RBACClient:         rbacStub,
		Timeout:            time.Second,
	}

	first, err := listHandler(provider)(context.Background(), mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"limit": 2,
			},
		},
		Header: func() http.Header {
			h := http.Header{}
			h.Set("X-Semaphore-User-ID", "11111111-2222-3333-4444-555555555555")
			return h
		}(),
	})
	if err != nil || first.IsError {
		t.Fatalf("first page failed: err=%v, res=%+v", err, first)
	}

	page1 := first.StructuredContent.(listResult)
	if len(page1.Organizations) != 2 {
		t.Fatalf("expected 2 orgs on first page, got %d", len(page1.Organizations))
	}
	if page1.Organizations[0].Name != "Alpha Org" || page1.Organizations[1].Name != "Beta Org" {
		t.Fatalf("unexpected sort order: %#v", page1.Organizations)
	}
	if page1.NextCursor == "" {
		t.Fatalf("expected next cursor for remaining items")
	}

	second, err := listHandler(provider)(context.Background(), mcp.CallToolRequest{
		Params: mcp.CallToolParams{
			Arguments: map[string]any{
				"limit":  2,
				"cursor": page1.NextCursor,
			},
		},
		Header: func() http.Header {
			h := http.Header{}
			h.Set("X-Semaphore-User-ID", "11111111-2222-3333-4444-555555555555")
			return h
		}(),
	})
	if err != nil || second.IsError {
		t.Fatalf("second page failed: err=%v, res=%+v", err, second)
	}

	page2 := second.StructuredContent.(listResult)
	if len(page2.Organizations) != 1 || page2.Organizations[0].Name != "Gamma Org" {
		t.Fatalf("unexpected second page data: %#v", page2.Organizations)
	}
	if page2.NextCursor != "" {
		t.Fatalf("expected no further pages, got cursor %q", page2.NextCursor)
	}
}

type organizationClientStub struct {
	orgpb.OrganizationServiceClient
	organizations   []*orgpb.Organization
	err             error
	describeRequest *orgpb.DescribeManyRequest
}

func (o *organizationClientStub) DescribeMany(ctx context.Context, in *orgpb.DescribeManyRequest, opts ...grpc.CallOption) (*orgpb.DescribeManyResponse, error) {
	o.describeRequest = in
	if o.err != nil {
		return nil, o.err
	}
	return &orgpb.DescribeManyResponse{Organizations: o.organizations}, nil
}

type rbacClientStub struct {
	rbacpb.RBACClient
	ids []string
	err error
}

func (r *rbacClientStub) ListAccessibleOrgs(ctx context.Context, in *rbacpb.ListAccessibleOrgsRequest, opts ...grpc.CallOption) (*rbacpb.ListAccessibleOrgsResponse, error) {
	if r.err != nil {
		return nil, r.err
	}
	return &rbacpb.ListAccessibleOrgsResponse{OrgIds: r.ids}, nil
}
