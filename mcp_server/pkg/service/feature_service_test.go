package service

import (
	"context"
	"errors"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
)

func TestNewFeatureService_UsesFeatureHubProviderByDefault(t *testing.T) {
	t.Setenv("ON_PREM", "")

	cache := newFakeCache()
	client := NewFeatureService("localhost:1234", cache, time.Second)

	svc, ok := client.(*featureService)
	require.True(t, ok, "expected concrete featureService implementation")
	assert.IsType(t, &feature.FeatureHubProvider{}, svc.provider)
}

func TestNewFeatureService_UsesYamlProviderWhenOnPrem(t *testing.T) {
	t.Setenv("ON_PREM", "true")
	t.Setenv("FEATURE_YAML_PATH", filepath.Join("..", "feature", "test_features.yml"))

	cache := newFakeCache()
	client := NewFeatureService("", cache, time.Second)

	svc, ok := client.(*featureService)
	require.True(t, ok, "expected concrete featureService implementation")
	require.IsType(t, &feature.YamlProvider{}, svc.provider)

	orgID := "org1"
	features, err := svc.ListOrganizationFeatures(orgID)
	require.NoError(t, err)

	assert.ElementsMatch(t, []feature.OrganizationFeature{
		{Name: "mcp_feature1", State: feature.Enabled, Quantity: 1},
	}, features)
}

func TestFeatureService_ListOrganizationFeaturesCachesResults(t *testing.T) {
	expected := []feature.OrganizationFeature{
		{Name: "feature-a", State: feature.Enabled, Quantity: 10},
		{Name: "feature-b", State: feature.Hidden, Quantity: 0},
	}

	cache := newFakeCache()
	provider := newFakeFeatureProvider(expected)
	service := &featureService{
		provider:    provider,
		cache:       cache,
		CallTimeout: time.Second,
	}

	orgID := "org-local"
	features, err := service.ListOrganizationFeatures(orgID)
	require.NoError(t, err)
	assert.ElementsMatch(t, expected, features)
	assert.Equal(t, 1, provider.CallCount())
	assert.Equal(t, 1, cache.setCalls)

	featuresFromCache, err := service.ListOrganizationFeatures(orgID)
	require.NoError(t, err)
	assert.ElementsMatch(t, expected, featuresFromCache)
	assert.Equal(t, 1, provider.CallCount(), "provider should not be called when cache hits")
	assert.Equal(t, 2, cache.getCalls, "cache Get should be invoked on each call")
}

func TestFeatureService_FeatureState(t *testing.T) {
	expected := []feature.OrganizationFeature{
		{Name: "feature-a", State: feature.Enabled, Quantity: 10},
		{Name: "feature-b", State: feature.Hidden, Quantity: 0},
	}

	cache := newFakeCache()
	provider := newFakeFeatureProvider(expected)
	service := &featureService{
		provider:    provider,
		cache:       cache,
		CallTimeout: time.Second,
	}

	state, err := service.FeatureState("org-local", "feature-a")
	require.NoError(t, err)
	assert.Equal(t, feature.Enabled, state)

	stateMissing, err := service.FeatureState("org-local", "feature-missing")
	require.NoError(t, err)
	assert.Equal(t, feature.Hidden, stateMissing)
}

func TestFeatureService_WithMockProviderAndYamlBackend(t *testing.T) {
	t.Setenv("ON_PREM", "true")
	t.Setenv("FEATURE_YAML_PATH", filepath.Join("..", "feature", "test_features.yml"))

	cache := &noopCache{}
	client := NewFeatureService("", cache, time.Second)

	features, err := client.ListOrganizationFeatures("org1")
	require.NoError(t, err)
	assert.ElementsMatch(t, []feature.OrganizationFeature{
		{Name: "mcp_feature1", State: feature.Enabled, Quantity: 1},
	}, features)

	state, err := client.FeatureState("org1", "mcp_feature1")
	require.NoError(t, err)
	assert.Equal(t, feature.Enabled, state)
}

func TestFeatureService_WithMockProviderAndStubbedCache(t *testing.T) {
	t.Setenv("ON_PREM", "")

	stubFeatures := []feature.OrganizationFeature{
		{Name: "feature-a", State: feature.Enabled, Quantity: 10},
		{Name: "feature-b", State: feature.Hidden, Quantity: 0},
	}

	cache := newFakeCache()
	cache.store["org-local"] = append([]feature.OrganizationFeature(nil), stubFeatures...)

	client := NewFeatureService("localhost:1234", cache, 10*time.Millisecond)

	state, err := client.FeatureState("org-local", "feature-a")
	require.NoError(t, err)
	assert.Equal(t, feature.Enabled, state)

	stateHidden, err := client.FeatureState("org-local", "feature-b")
	require.NoError(t, err)
	assert.Equal(t, feature.Hidden, stateHidden)
}

type fakeCache struct {
	mu       sync.Mutex
	store    map[string][]feature.OrganizationFeature
	getCalls int
	setCalls int
}

func newFakeCache() *fakeCache {
	return &fakeCache{
		store: make(map[string][]feature.OrganizationFeature),
	}
}

func (c *fakeCache) Get(_ context.Context, key string, value interface{}) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.getCalls++

	features, ok := c.store[key]
	if !ok {
		return errors.New("cache miss")
	}

	slicePtr, ok := value.(*[]feature.OrganizationFeature)
	if !ok {
		return errors.New("invalid value type")
	}

	*slicePtr = append((*slicePtr)[:0], features...)
	return nil
}

func (c *fakeCache) Set(_ context.Context, key string, value interface{}) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.setCalls++

	features, ok := value.([]feature.OrganizationFeature)
	if !ok {
		return errors.New("invalid cache value")
	}

	c.store[key] = append([]feature.OrganizationFeature(nil), features...)
	return nil
}

type fakeFeatureProvider struct {
	mu       sync.Mutex
	features []feature.OrganizationFeature
	calls    int
}

func newFakeFeatureProvider(features []feature.OrganizationFeature) *fakeFeatureProvider {
	return &fakeFeatureProvider{
		features: append([]feature.OrganizationFeature(nil), features...),
	}
}

func (p *fakeFeatureProvider) ListFeatures(_ string) ([]feature.OrganizationFeature, error) {
	return p.listFeatures()
}

func (p *fakeFeatureProvider) ListFeaturesWithContext(_ context.Context, _ string) ([]feature.OrganizationFeature, error) {
	return p.listFeatures()
}

func (p *fakeFeatureProvider) listFeatures() ([]feature.OrganizationFeature, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	p.calls++

	return append([]feature.OrganizationFeature(nil), p.features...), nil
}

func (p *fakeFeatureProvider) CallCount() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.calls
}

type noopCache struct{}

func (n *noopCache) Get(context.Context, string, interface{}) error {
	return errors.New("cache miss")
}

func (n *noopCache) Set(context.Context, string, interface{}) error {
	return nil
}
