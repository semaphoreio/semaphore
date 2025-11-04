package service_test

import (
	"context"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi/stubs"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/service"
)

func TestFeatureService_WithMockProviderAndYamlBackend(t *testing.T) {
	t.Setenv("ON_PREM", "true")
	t.Setenv("FEATURE_YAML_PATH", filepath.Join("..", "feature", "test_features.yml"))

	cache := &noopCache{}
	client := service.NewFeatureService("", cache, time.Second)

	mockProvider := &internalapi.MockProvider{FeaturesService: client}

	features, err := mockProvider.Features().ListOrganizationFeatures("org1")
	require.NoError(t, err)
	assert.ElementsMatch(t, []feature.OrganizationFeature{
		{Name: "mcp_feature1", State: feature.Enabled, Quantity: 1},
	}, features)

	state, err := mockProvider.Features().FeatureState("org1", "mcp_feature1")
	require.NoError(t, err)
	assert.Equal(t, feature.Enabled, state)
}

func TestFeatureService_WithMockProviderAndStubbedCache(t *testing.T) {
	t.Setenv("ON_PREM", "")

	stubProvider := stubs.New()
	stubFeatures, err := stubProvider.Features().ListOrganizationFeatures("org-local")
	require.NoError(t, err)

	cache := &presetCache{features: stubFeatures}
	client := service.NewFeatureService("localhost:1234", cache, 10*time.Millisecond)

	mockProvider := &internalapi.MockProvider{FeaturesService: client}

	state, err := mockProvider.Features().FeatureState("org-local", "feature-a")
	require.NoError(t, err)
	assert.Equal(t, feature.Enabled, state)

	stateHidden, err := mockProvider.Features().FeatureState("org-local", "feature-b")
	require.NoError(t, err)
	assert.Equal(t, feature.Hidden, stateHidden)
}

type noopCache struct{}

func (n *noopCache) Get(context.Context, string, interface{}) error {
	return errors.New("cache miss")
}

func (n *noopCache) Set(context.Context, string, interface{}) error {
	return nil
}

type presetCache struct {
	features []feature.OrganizationFeature
}

func (p *presetCache) Get(_ context.Context, _ string, value interface{}) error {
	slicePtr, ok := value.(*[]feature.OrganizationFeature)
	if !ok {
		return errors.New("invalid target type")
	}

	*slicePtr = append((*slicePtr)[:0], p.features...)
	return nil
}

func (p *presetCache) Set(context.Context, string, interface{}) error {
	return nil
}
