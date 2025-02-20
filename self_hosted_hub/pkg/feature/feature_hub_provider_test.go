package feature

import (
	"testing"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/config"
	"github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	"github.com/stretchr/testify/assert"
)

func Test__FeatureHubProvider(t *testing.T) {
	grpcmock.Start()

	t.Run("fetches feature configuration from featurehub", func(t *testing.T) {
		provider, err := NewFeatureHubProvider(config.FeatureAPIEndpoint())

		assert.Nil(t, err)

		orgID := "org1"
		features, err := provider.ListFeatures(orgID)

		assert.Nil(t, err)
		assert.Equal(t, []OrganizationFeature{
			{Name: "self_hosted_agents", State: Enabled, Quantity: 0x5},
		}, features)
	})
}
