package fetcher

import (
	"flag"
	"log"
	"runtime/debug"
	"time"

	gorm "github.com/jinzhu/gorm"
	"github.com/renderedtext/go-watchman"
	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
	tokenstore "github.com/semaphoreio/semaphore/repohub/pkg/tokenstore"
)

//
// Worker for pre-fetching and storing repositories.
//

type Fetcher struct {
	db         *gorm.DB
	tokenStore *tokenstore.TokenStore
}

func NewFetcher(db *gorm.DB) *Fetcher {
	return &Fetcher{
		db:         db,
		tokenStore: tokenstore.New(),
	}
}

func (f *Fetcher) Run() {
	for {
		time.Sleep(60 * time.Second)

		f.panicHandler(func() {
			f.SyncAll(1 * time.Second)
		})
	}
}

func (f *Fetcher) SyncAll(sleepBetweenClones time.Duration) {
	defer watchman.Benchmark(time.Now(), "fetcher.SyncAll")

	repos, err := models.ListAllRepositories(f.db)

	if err != nil {
		log.Printf("error: %s", err.Error())
		return
	}

	totalRepoCount := len(repos)

	for i := range repos {
		f.panicHandler(func() {
			repo := repos[i]
			performedWork := f.Sync(i+1, totalRepoCount, &repo)

			if performedWork {
				time.Sleep(sleepBetweenClones)
			}
		})
	}
}

func (f *Fetcher) putRepoInQuarantine(repo *gitrekt.Repository, reason gitrekt.QuarantineReason) {
	err := repo.PutInQuarantine(reason)

	if err != nil {
		log.Printf("Failed to put repo in quarantine, err: %s", err.Error())
	}
}

func (f *Fetcher) Sync(index int, totalRepoCount int, r *models.Repository) bool {
	repo := f.toGitRektRepository(r)

	if repo.Exists() {
		return false
	}

	lock := repo.AcquireLock()
	if lock == nil {
		return false
	}
	defer repo.ReleaseLock(lock)

	defer watchman.Benchmark(time.Now(), "fetcher.Sync")

	token, err := f.findRepoToken(r)
	if err != nil {
		log.Printf("Failed to lookup repository token, err: %s", err.Error())
		return false
	}

	repo.Credentials = &gitrekt.Credentials{
		Username: "x-oauth-token",
		Password: token,
	}

	op := gitrekt.NewUpdateOrCloneOperation(repo, "")

	log.Printf("Syncing repo %d/%d START: Repo %s from %s",
		index,
		totalRepoCount,
		repo.Name,
		repo.HttpURL)

	err = op.Clone()

	if err != nil {
		quarantined := false
		quarantinedReason := ""

		if _, ok := err.(*gitrekt.TimeoutError); ok {
			f.putRepoInQuarantine(repo, gitrekt.QuarantineReasonCloneTimeout)

			quarantined = true
			quarantinedReason = string(gitrekt.QuarantineReasonCloneTimeout)
		}

		if _, ok := err.(*gitrekt.AuthFailedError); ok {
			f.putRepoInQuarantine(repo, gitrekt.QuarantineReasonNotFound)

			quarantined = true
			quarantinedReason = string(gitrekt.QuarantineReasonNotFound)
		}

		if _, ok := err.(*gitrekt.NotFoundError); ok {
			f.putRepoInQuarantine(repo, gitrekt.QuarantineReasonNotFound)

			quarantined = true
			quarantinedReason = string(gitrekt.QuarantineReasonNotFound)
		}

		log.Printf("Syncing repo %d/%d ERROR: Repo %s from %s in %fs. Quarantined: %t %s",
			index,
			totalRepoCount,
			repo.Name,
			repo.HttpURL,
			op.Duration(),
			quarantined,
			quarantinedReason,
		)
	} else {
		log.Printf("Syncing repo %d/%d FINISH: Repo %s from %s in %fs",
			index,
			totalRepoCount,
			repo.Name,
			repo.HttpURL,
			op.Duration())
	}

	return true
}

func (f *Fetcher) findRepoToken(r *models.Repository) (string, error) {
	return f.tokenStore.FindRepoToken(r)
}

func (f *Fetcher) toGitRektRepository(r *models.Repository) *gitrekt.Repository {
	token, err := f.findRepoToken(r)
	if err != nil {
		log.Printf("Failed to find repo token: %v", err)
		return r.ToGitrektRepository()
	}
	return tokenstore.ToGitRektRepository(r, token)
}

func (f *Fetcher) panicHandler(fnc func()) {
	defer func() {
		if p := recover(); p != nil {
			log.Println(p)
			log.Println(string(debug.Stack()))

			if flag.Lookup("test.v") != nil {
				panic(p)
			}
		}
	}()

	fnc()
}
