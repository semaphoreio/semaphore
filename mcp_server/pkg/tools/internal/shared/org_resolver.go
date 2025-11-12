package shared

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	orgpb "github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/organization"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internalapi"
	"google.golang.org/grpc"
)

// OrgNameResolver resolves organization IDs to human-readable names.
type OrgNameResolver interface {
	Resolve(ctx context.Context, orgID string) (string, error)
}

type orgDescriber interface {
	Describe(ctx context.Context, in *orgpb.DescribeRequest, opts ...grpc.CallOption) (*orgpb.DescribeResponse, error)
}

type cachedOrgResolver struct {
	client  orgDescriber
	timeout time.Duration
	ttl     time.Duration
	now     func() time.Time

	mu    sync.RWMutex
	cache map[string]orgCacheEntry
}

type orgCacheEntry struct {
	name      string
	expiresAt time.Time
}

var (
	orgResolver     OrgNameResolver
	orgResolverLock sync.RWMutex
	orgResolverInit sync.Once
)

// SetOrgNameResolver allows the application to provide a resolver used by metric helpers.
func SetOrgNameResolver(resolver OrgNameResolver) {
	orgResolverLock.Lock()
	defer orgResolverLock.Unlock()
	orgResolver = resolver
}

func getOrgNameResolver() OrgNameResolver {
	orgResolverLock.RLock()
	defer orgResolverLock.RUnlock()
	return orgResolver
}

// NewCachedOrgNameResolver returns a resolver backed by the organization gRPC client with basic caching.
func NewCachedOrgNameResolver(provider internalapi.Provider, ttl time.Duration) OrgNameResolver {
	if provider == nil {
		return nil
	}
	client := provider.Organizations()
	if client == nil {
		return nil
	}
	if ttl <= 0 {
		ttl = 30 * time.Minute
	}
	return &cachedOrgResolver{
		client:  client,
		timeout: provider.CallTimeout(),
		ttl:     ttl,
		now:     time.Now,
		cache:   make(map[string]orgCacheEntry),
	}
}

// ConfigureDefaultOrgResolver installs a cached resolver backed by the provided internal API clients.
func ConfigureDefaultOrgResolver(provider internalapi.Provider) {
	if provider == nil {
		return
	}
	orgResolverInit.Do(func() {
		if resolver := NewCachedOrgNameResolver(provider, 30*time.Minute); resolver != nil {
			SetOrgNameResolver(resolver)
		}
	})
}

func (r *cachedOrgResolver) Resolve(ctx context.Context, orgID string) (string, error) {
	if r == nil {
		return "", fmt.Errorf("resolver is not configured")
	}

	key := strings.TrimSpace(strings.ToLower(orgID))
	if key == "" {
		return "", fmt.Errorf("organization id is required")
	}

	if name, ok := r.lookup(key); ok {
		return name, nil
	}

	callCtx := ctx
	var cancel context.CancelFunc
	if r.timeout > 0 {
		callCtx, cancel = context.WithTimeout(ctx, r.timeout)
		defer cancel()
	}

	resp, err := r.client.Describe(callCtx, &orgpb.DescribeRequest{OrgId: key})
	if err != nil {
		return "", err
	}
	if err := CheckResponseStatus(resp.GetStatus()); err != nil {
		return "", err
	}
	org := resp.GetOrganization()
	if org == nil {
		return "", fmt.Errorf("describe response missing organization payload")
	}
	name := strings.TrimSpace(org.GetName())
	if name == "" {
		name = strings.TrimSpace(org.GetOrgUsername())
	}
	if name == "" {
		name = key
	}

	r.store(key, name)
	return name, nil
}

func (r *cachedOrgResolver) lookup(key string) (string, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	entry, ok := r.cache[key]
	if !ok {
		return "", false
	}
	if r.ttl > 0 && r.now().After(entry.expiresAt) {
		return "", false
	}
	return entry.name, true
}

func (r *cachedOrgResolver) store(key, name string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.cache[key] = orgCacheEntry{
		name:      name,
		expiresAt: r.now().Add(r.ttl),
	}
}
