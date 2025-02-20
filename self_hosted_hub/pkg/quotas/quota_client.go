package quotas

import (
	"context"
	"encoding/json"
	"time"

	"github.com/dgraph-io/ristretto"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	log "github.com/sirupsen/logrus"

	watchman "github.com/renderedtext/go-watchman"
)

const (
	SelfHostedAgentsFeature = "self_hosted_agents"
	CacheKeyCost            = 1
)

type QuotaClient struct {
	Cache           *ristretto.Cache
	featureProvider feature.Provider
}

type OrganizationQuota struct {
	Enabled  bool
	Quantity uint32
}

func NewQuotaClient(featureProvider feature.Provider) (*QuotaClient, error) {

	/*
	 * We keep the quota in the cache for at most 10000 orgs at the same time (MaxCost=10000).
	 * The information we have to keep for each cache key is pretty small (~32 bytes),
	 * so for a full cache, we'd have 320k of memory.
	 */
	ristrettoCache, err := ristretto.NewCache(&ristretto.Config{
		NumCounters: 100000,
		MaxCost:     10000,
		BufferItems: 64,
		Metrics:     false,
	})

	if err != nil {
		return nil, err
	}

	return &QuotaClient{Cache: ristrettoCache, featureProvider: featureProvider}, nil
}

func (c *QuotaClient) GetQuota(orgID string) (*OrganizationQuota, error) {
	return c.getQuotaWithTTL(context.Background(), orgID, 5*time.Minute)
}

func (c *QuotaClient) GetQuotaWithContext(ctx context.Context, orgID string) (*OrganizationQuota, error) {
	return c.getQuotaWithTTL(ctx, orgID, 5*time.Minute)
}

func (c *QuotaClient) getQuotaWithTTL(ctx context.Context, orgID string, ttl time.Duration) (*OrganizationQuota, error) {
	value, found := c.Cache.Get(orgID)
	if found && value != nil {
		var orgQuota = OrganizationQuota{}
		var err error
		if err = json.Unmarshal(value.([]byte), &orgQuota); err == nil {
			return &orgQuota, nil
		}

		// If there's an error unmarshaling the organization quota,
		// we need to load it again, so no return here.
		log.Errorf("Error unmarshaling organization quota for '%s': %v", orgID, err)
	}

	log.Infof("Loading quota for organization %s", orgID)
	orgQuota, err := c.loadQuota(ctx, orgID)
	if err != nil {
		_ = watchman.IncrementWithTags("organization.quota.error", []string{orgID})
		log.Errorf("Error loading quota for %s: %v", orgID, err)
		return nil, err
	}

	// If there's an error marshaling the organization quota,
	// we don't store it in the cache and just return it.
	orgQuotaBytes, err := json.Marshal(orgQuota)
	if err != nil {
		log.Errorf("Error marshaling organization quota for %s: %v", orgID, err)
		return orgQuota, nil
	}

	log.Infof("Storing quota for organization %s in cache: %v...", orgID, orgQuota)
	saved := c.Cache.SetWithTTL(orgID, orgQuotaBytes, CacheKeyCost, ttl)

	// Again, if the org quota was not cached, there's nothing we can do,
	// so we just log that and move on.
	if !saved {
		log.Infof("Quota for organization %s not saved in cache.", orgID)
	}

	return orgQuota, nil
}

func (c *QuotaClient) loadQuota(ctx context.Context, orgID string) (*OrganizationQuota, error) {
	defer watchman.Benchmark(time.Now(), "organization.quota")

	organizationQuota := &OrganizationQuota{
		Enabled:  false,
		Quantity: 0,
	}

	features, err := c.featureProvider.ListFeaturesWithContext(ctx, orgID)

	if err != nil {
		log.Printf("Error getting features for org %s: %s", orgID, err)
		return nil, err
	}

	for _, organizationFeature := range features {
		if organizationFeature.Name == SelfHostedAgentsFeature {
			organizationQuota.Enabled = organizationFeature.State == feature.Enabled
			organizationQuota.Quantity = organizationFeature.Quantity
		}
	}

	return organizationQuota, nil
}

/*
 * Note: this is only used in tests.
 *
 * Due to ristretto's eventual consistency approach,
 * SET operations are not immediately reflected in the cache.
 * See: https://dgraph.io/blog/post/introducing-ristretto-high-perf-go-cache/.
 *
 * We use this function in tests to help assert the status of an organization in the cache.
 */
func (c *QuotaClient) isCached(orgID string) bool {
	_, found := c.Cache.Get(orgID)
	return found
}

/*
 * Note: this is only used in tests.
 *
 * During tests, we need a way to clear the cache
 * to make a quota change is picked up by this client.
 */
func (c *QuotaClient) Clear(orgID string) {
	c.Cache.Del(orgID)
}
