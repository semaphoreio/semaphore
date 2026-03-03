package feature_test

import (
	"context"
	"net"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	feature "github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	featurepb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/feature"
	"github.com/semaphoreio/semaphore/mcp_server/test/support"
)

func TestNewFeatureHubProvider_ReturnsErrorWhenEndpointMissing(t *testing.T) {
	provider, err := feature.NewFeatureHubProvider("")
	require.Nil(t, provider)
	require.Error(t, err)
}

func TestFeatureHubProvider_ListFeatures(t *testing.T) {
	stub := support.NewFeatureHubServiceStub()
	stub.SetResponse(&featurepb.ListOrganizationFeaturesResponse{
		OrganizationFeatures: []*featurepb.OrganizationFeature{
			{
				Feature: &featurepb.Feature{Type: "feature-enabled"},
				Availability: &featurepb.Availability{
					State:    featurepb.Availability_ENABLED,
					Quantity: 5,
				},
			},
			{
				Feature: &featurepb.Feature{Type: "feature-zero"},
				Availability: &featurepb.Availability{
					State:    featurepb.Availability_ZERO_STATE,
					Quantity: 3,
				},
			},
			{
				Feature: &featurepb.Feature{Type: "feature-hidden"},
				Availability: &featurepb.Availability{
					State:    featurepb.Availability_HIDDEN,
					Quantity: 1,
				},
			},
			{
				Feature: &featurepb.Feature{Type: "feature-unknown"},
				Availability: &featurepb.Availability{
					State:    featurepb.Availability_State(99),
					Quantity: 7,
				},
			},
		},
	})

	addr, opt, cleanup := startFeatureHubServer(t, stub)
	t.Cleanup(cleanup)

	provider, err := feature.NewFeatureHubProvider(addr, opt)
	require.NoError(t, err)

	orgFeatures, err := provider.ListFeatures("org-123")
	require.NoError(t, err)
	require.Equal(t, []feature.OrganizationFeature{
		{Name: "feature-enabled", Quantity: 5, State: feature.Enabled},
		{Name: "feature-zero", Quantity: 3, State: feature.ZeroState},
		{Name: "feature-hidden", Quantity: 1, State: feature.Hidden},
		{Name: "feature-unknown", Quantity: 7, State: feature.Hidden},
	}, orgFeatures)

	request := stub.LastRequest()
	require.NotNil(t, request)
	require.Equal(t, "org-123", request.GetOrgId())
	require.Equal(t, 1, stub.CallCount())
}

func TestFeatureHubProvider_ListFeaturesWithContextPropagatesError(t *testing.T) {
	stub := support.NewFeatureHubServiceStub()
	stub.SetError(status.Error(codes.Internal, "feature service unavailable"))

	addr, opt, cleanup := startFeatureHubServer(t, stub)
	t.Cleanup(cleanup)

	provider, err := feature.NewFeatureHubProvider(addr, opt)
	require.NoError(t, err)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()

	orgFeatures, err := provider.ListFeaturesWithContext(ctx, "org-123")
	require.Error(t, err)
	require.Nil(t, orgFeatures)

	require.Equal(t, 1, stub.CallCount())
}

func startFeatureHubServer(t *testing.T, stub *support.FeatureHubServiceStub) (string, feature.FeatureHubProviderOption, func()) {
	t.Helper()

	listener := bufconn.Listen(1_048_576)

	server := grpc.NewServer()
	featurepb.RegisterFeatureServiceServer(server, stub)

	go func() {
		_ = server.Serve(listener)
	}()

	option := feature.WithDialContext(func(ctx context.Context, _ string) (net.Conn, error) {
		return listener.Dial()
	})

	return "bufnet", option, func() {
		server.GracefulStop()
		_ = listener.Close()
	}
}
