package organizations

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/mark3labs/mcp-go/mcp"
	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"

	responsepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/response_status"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"

	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func TestListOrganizationsSummary(t *testing.T) {
	stub := &organizationClientStub{
		response: &orgpb.ListResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Organizations: []*orgpb.Organization{
				{
					OrgId:       "org-1",
					Name:        "Example Org",
					OrgUsername: "example",
					CreatedAt:   timestamppb.New(time.Unix(1_700_000_000, 0)),
					Verified:    true,
				},
			},
			NextPageToken: "next",
		},
	}

	provider := &internalapi.MockProvider{
		OrganizationClient: stub,
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

	got, ok := res.StructuredContent.(listResult)
	if !ok {
		t.Fatalf("unexpected structured content type: %T", res.StructuredContent)
	}
	if len(got.Organizations) != 1 {
		t.Fatalf("expected 1 organization, got %d", len(got.Organizations))
	}
	if got.NextCursor != "next" {
		t.Fatalf("expected next cursor 'next', got %q", got.NextCursor)
	}
	if got.Organizations[0].Name != "Example Org" {
		t.Fatalf("unexpected organization name: %q", got.Organizations[0].Name)
	}
	if got.Organizations[0].Details != nil {
		t.Fatalf("expected summary mode to omit details")
	}
}

func TestListOrganizationsDetailed(t *testing.T) {
	stub := &organizationClientStub{
		response: &orgpb.ListResponse{
			Status: &responsepb.ResponseStatus{Code: responsepb.ResponseStatus_OK},
			Organizations: []*orgpb.Organization{
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
		},
	}

	provider := &internalapi.MockProvider{
		OrganizationClient: stub,
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

	got, ok := res.StructuredContent.(listResult)
	if !ok || len(got.Organizations) != 1 {
		t.Fatalf("unexpected structured content: %+v", res.StructuredContent)
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

type organizationClientStub struct {
	orgpb.OrganizationServiceClient
	response *orgpb.ListResponse
	err      error
	request  *orgpb.ListRequest
}

func (o *organizationClientStub) List(ctx context.Context, in *orgpb.ListRequest, opts ...grpc.CallOption) (*orgpb.ListResponse, error) {
	o.request = in
	if o.err != nil {
		return nil, o.err
	}
	return o.response, nil
}
