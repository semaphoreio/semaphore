package support

import "github.com/semaphoreio/semaphore/mcp_server/pkg/feature"

// FeatureClientStub allows tests to control feature flag responses.
type FeatureClientStub struct {
	State      feature.State
	StateError error
	Features   []feature.OrganizationFeature
}

func (f FeatureClientStub) ListOrganizationFeatures(string) ([]feature.OrganizationFeature, error) {
	if f.Features == nil {
		return nil, nil
	}
	return append([]feature.OrganizationFeature(nil), f.Features...), nil
}

func (f FeatureClientStub) FeatureState(string, string) (feature.State, error) {
	if f.StateError != nil {
		return feature.Hidden, f.StateError
	}
	return f.State, nil
}
