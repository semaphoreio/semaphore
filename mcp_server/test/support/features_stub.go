package support

import "github.com/semaphoreio/semaphore/mcp_server/pkg/feature"

// FeatureClientStub allows tests to control feature flag responses.
type FeatureClientStub struct {
	State       feature.State
	StateError  error
	Features    []feature.OrganizationFeature
	States      map[string]feature.State
	StateErrors map[string]error
}

func (f FeatureClientStub) ListOrganizationFeatures(string) ([]feature.OrganizationFeature, error) {
	if f.Features == nil {
		return nil, nil
	}
	return append([]feature.OrganizationFeature(nil), f.Features...), nil
}

func (f FeatureClientStub) FeatureState(_ string, featureName string) (feature.State, error) {
	if len(f.StateErrors) > 0 {
		if err, ok := f.StateErrors[featureName]; ok {
			return feature.Hidden, err
		}
	}
	if f.StateError != nil {
		return feature.Hidden, f.StateError
	}
	if len(f.States) > 0 {
		if state, ok := f.States[featureName]; ok {
			return state, nil
		}
	}
	return f.State, nil
}
