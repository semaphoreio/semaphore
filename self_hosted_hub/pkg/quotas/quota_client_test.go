package quotas

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/config"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	"github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	"github.com/stretchr/testify/assert"
)

func Test__QuotaClient(t *testing.T) {
	grpcmock.Start()

	provider, err := feature.NewFeatureHubProvider(config.FeatureAPIEndpoint())
	assert.Nil(t, err)

	client, err := NewQuotaClient(provider)
	assert.Nil(t, err)

	t.Run("caches organization quota", func(t *testing.T) {
		orgID := "org1"
		assert.False(t, client.isCached(orgID))

		quota, err := client.GetQuota(orgID)

		assert.Nil(t, err)
		assert.Equal(t, OrganizationQuota{Enabled: true, Quantity: 5}, *quota)
		assert.Eventually(t, func() bool { return client.isCached(orgID) }, time.Second, 250*time.Millisecond)
	})

	t.Run("expires organization quota", func(t *testing.T) {
		orgID := "org2"
		assert.False(t, client.isCached(orgID))

		quota, err := client.getQuotaWithTTL(context.Background(), orgID, 5*time.Second)
		assert.Nil(t, err)

		assert.Equal(t, OrganizationQuota{Enabled: true, Quantity: 5}, *quota)

		// org is cached
		assert.Eventually(t, func() bool { return client.isCached(orgID) }, time.Second, 250*time.Millisecond)

		// org expires
		assert.Eventually(t, func() bool { return !client.isCached(orgID) }, 10*time.Second, time.Second)
	})

	t.Run("cancellation", func(t *testing.T) {
		os.Setenv("SELF_HOSTED_QUOTAS", "timeout")
		defer func() {
			os.Setenv("SELF_HOSTED_QUOTAS", "")
		}()

		orgID := "org3"
		ctx, cancelFunc := context.WithTimeout(context.Background(), time.Second)
		defer cancelFunc()
		_, err := client.GetQuotaWithContext(ctx, orgID)
		assert.ErrorContains(t, err, "context deadline exceeded")
	})
}
