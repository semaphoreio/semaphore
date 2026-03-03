// Package feature holds the feature provider interface and its implementations.
package feature

import (
	"context"
	"errors"
	"net"
	"time"

	"google.golang.org/grpc"

	"github.com/renderedtext/go-watchman"
	pb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/feature"
)

type FeatureHubProvider struct {
	grpcEndpoint string
	dialContext  DialContextFunc
}

type DialContextFunc func(ctx context.Context, addr string) (net.Conn, error)

type FeatureHubProviderOption func(*FeatureHubProvider)

// WithDialContext overrides the default transport dialer used by the provider.
// It is mainly intended for tests where an in-memory listener (for example
// google.golang.org/grpc/test/bufconn) replaces a real network connection.
func WithDialContext(dialer DialContextFunc) FeatureHubProviderOption {
	return func(p *FeatureHubProvider) {
		p.dialContext = dialer
	}
}

func NewFeatureHubProvider(grpcEndpoint string, opts ...FeatureHubProviderOption) (*FeatureHubProvider, error) {
	if grpcEndpoint == "" {
		return nil, errors.New("FeatureHub configuration is invalid, missing grpc endpoint is not set")
	}
	provider := &FeatureHubProvider{grpcEndpoint: grpcEndpoint}
	for _, opt := range opts {
		opt(provider)
	}
	return provider, nil
}

func (p *FeatureHubProvider) ListFeatures(orgID string) ([]OrganizationFeature, error) {
	return p.ListFeaturesWithContext(context.Background(), orgID)
}

func (p *FeatureHubProvider) ListFeaturesWithContext(ctx context.Context, orgID string) ([]OrganizationFeature, error) {
	defer watchman.Benchmark(time.Now(), "feature_hub.list_organization_features.duration")
	conn, err := grpc.DialContext(ctx, p.grpcEndpoint, p.dialOptions()...)
	if err != nil {
		return nil, err
	}

	defer conn.Close()

	client := pb.NewFeatureServiceClient(conn)
	req := pb.ListOrganizationFeaturesRequest{OrgId: orgID}

	response, err := client.ListOrganizationFeatures(ctx, &req)
	if err != nil {
		_ = watchman.Increment("feature_hub.list_organization_features.failure")
		return nil, err
	}

	organizationFeatures := make([]OrganizationFeature, 0, len(response.OrganizationFeatures))
	for _, orgFeature := range response.OrganizationFeatures {
		organizationFeatures = append(organizationFeatures, OrganizationFeature{
			Name:     orgFeature.Feature.Type,
			Quantity: orgFeature.Availability.Quantity,
			State:    stateOfFeature(orgFeature),
		})
	}

	_ = watchman.Increment("feature_hub.list_organization_features.success")
	return organizationFeatures, nil
}

func stateOfFeature(orgFeature *pb.OrganizationFeature) State {
	switch orgFeature.Availability.State {
	case pb.Availability_ENABLED:
		return Enabled
	case pb.Availability_HIDDEN:
		return Hidden
	case pb.Availability_ZERO_STATE:
		return ZeroState
	default:
		return Hidden
	}
}

func (p *FeatureHubProvider) dialOptions() []grpc.DialOption {
	opts := []grpc.DialOption{grpc.WithInsecure()}
	if p.dialContext != nil {
		opts = append(opts, grpc.WithContextDialer(p.dialContext))
	}
	return opts
}
