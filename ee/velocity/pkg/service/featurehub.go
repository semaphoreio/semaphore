// Package service holds grpc service's client implementations
package service

import (
	"context"
	"encoding/gob"
	"log"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/feature"
)

type featureHub struct {
	provider feature.Provider
	cache    CacheClient
}

// Register all the types that we want to store in the cache
func init() {
	gob.Register([]feature.OrganizationFeature{})
}

type FeatureHubClient interface {
	ListOrganizationFeatures(organizationId string) ([]feature.OrganizationFeature, error)
	FeatureState(organizationId string, featureName string) (feature.State, error)
}

func NewFeatureHubService(featureHubEndpoint string, cache CacheClient) FeatureHubClient {
	var provider feature.Provider
	if os.Getenv("ON_PREM") != "true" {
		provider = newFeatureHubGrpcProvider(featureHubEndpoint)
	} else {
		provider = newFeatureHubYamlProvider()
	}
	return &featureHub{provider: provider, cache: cache}
}

func newFeatureHubGrpcProvider(featureHubEndpoint string) feature.Provider {
	provider, err := feature.NewFeatureHubProvider(featureHubEndpoint)
	if err != nil {
		log.Panicf("Failed to create Grpc feature provider: %v", err)
	}
	return provider
}

func newFeatureHubYamlProvider() feature.Provider {
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

func (c *featureHub) FeatureState(organizationId string, featureName string) (feature.State, error) {
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

func (c *featureHub) ListOrganizationFeatures(organizationId string) ([]feature.OrganizationFeature, error) {
	var cachedResponse []feature.OrganizationFeature
	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
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
