package fetcher_test

import (
	"testing"
	"time"

	"github.com/magiconair/properties/assert"
	"github.com/semaphoreio/semaphore/repohub/pkg/fetcher"
	support "github.com/semaphoreio/semaphore/repohub/test/support"
)

func Test__PrefetchingRepositories__NotExistingRepository(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateNotExistingRepository().ToGitrektRepository()

	assert.Equal(t, repo.Exists(), false)

	fetcher.NewFetcher(support.DB).SyncAll(0 * time.Second)

	assert.Equal(t, repo.Exists(), false)
}

func Test__PrefetchingRepositories__GithubTokenIntegration(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateGithubTokenRepository().ToGitrektRepository()

	assert.Equal(t, repo.Exists(), false)

	fetcher.NewFetcher(support.DB).SyncAll(0 * time.Second)

	assert.Equal(t, repo.Exists(), true)
}

func Test__PrefetchingRepositories__GithubAppIntegration(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateGithubAppRepository().ToGitrektRepository()

	assert.Equal(t, repo.Exists(), false)

	fetcher.NewFetcher(support.DB).SyncAll(0 * time.Second)

	assert.Equal(t, repo.Exists(), true)
}

func Test__PrefetchingRepositories__GithubAppNotInstalledIntegration(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateGithubAppNotInstalledRepository().ToGitrektRepository()

	assert.Equal(t, repo.Exists(), false)

	fetcher.NewFetcher(support.DB).SyncAll(0 * time.Second)

	assert.Equal(t, repo.Exists(), false)
}
