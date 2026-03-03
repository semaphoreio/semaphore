// Package service holds grpc service's client implementations
package service

import (
	"context"
	"encoding/gob"
	"log"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/feature"
)

type featureService struct {
	provider    feature.FeatureProvider
	cache       CacheClient
	CallTimeout time.Duration
}

// Register all the types that we want to store in the cache
func init() {
	gob.Register([]feature.OrganizationFeature{})
}

type FeatureClient interface {
	ListOrganizationFeatures(organizationId string) ([]feature.OrganizationFeature, error)
	FeatureState(organizationId string, featureName string) (feature.State, error)
}

func NewFeatureService(featureHubEndpoint string, cache CacheClient, callTimeout time.Duration) FeatureClient {
	var provider feature.FeatureProvider
	if os.Getenv("ON_PREM") != "true" {
		provider = newFeatureServiceGrpcProvider(featureHubEndpoint)
	} else {
		provider = newFeatureServiceYamlProvider()
	}
	return &featureService{provider: provider, cache: cache, CallTimeout: callTimeout}
}

func newFeatureServiceGrpcProvider(featureHubEndpoint string) feature.FeatureProvider {
	provider, err := feature.NewFeatureHubProvider(featureHubEndpoint)
	if err != nil {
		log.Panicf("Failed to create Grpc feature provider: %v", err)
	}
	return provider
}

func newFeatureServiceYamlProvider() feature.FeatureProvider {
	featureYamlPath := os.Getenv("FEATURE_YAML_PATH")
	if featureYamlPath == "" {
		featureYamlPath = "/app/features.yml"
	}

	provider, err := feature.NewYamlProvider(featureYamlPath)
	if err != nil {
		log.Panicf("Failed to create YAML feature provider: %v", err)
	}
	return provider
}

func (c *featureService) FeatureState(organizationId string, featureName string) (feature.State, error) {
	orgFeatures, err := c.ListOrganizationFeatures(organizationId)
	if err != nil {
		return feature.Hidden, err
	}

	for _, feature := range orgFeatures {
		if feature.Name == featureName {
			return feature.State, nil
		}
	}

	return feature.Hidden, nil
}

func (c *featureService) ListOrganizationFeatures(organizationId string) ([]feature.OrganizationFeature, error) {
	var cachedResponse []feature.OrganizationFeature
	tCtx, cancel := context.WithTimeout(context.Background(), c.CallTimeout)
	defer cancel()

	err := c.cache.Get(tCtx, organizationId, &cachedResponse)
	if err != nil {
		orgFeatures, err := c.provider.ListFeaturesWithContext(tCtx, organizationId)
		if err != nil {
			return nil, err
		}

		err = c.cache.Set(tCtx, organizationId, orgFeatures)
		if err != nil {
			return nil, err
		}

		return orgFeatures, nil
	}

	return cachedResponse, nil
}
