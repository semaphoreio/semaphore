package feature

import (
	"testing"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/test/support"
	"github.com/stretchr/testify/assert"
)

func Test__FeatureHubProvider(t *testing.T) {
	support.StartFakeServers()

	t.Run("fetches feature configuration from featurehub", func(t *testing.T) {
		provider, err := NewFeatureHubProvider(config.FeatureHubEndpoint())

		assert.Nil(t, err)

		orgID := "org1"
		features, err := provider.ListFeatures(orgID)

		assert.Nil(t, err)
		assert.Equal(t, []OrganizationFeature{
			{Name: "superjerry_tests", State: Enabled, Quantity: 1},
		}, features)
	})
}
