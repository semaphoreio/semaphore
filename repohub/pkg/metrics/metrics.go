package metrics

import (
	"flag"
	"log"
	"runtime/debug"
	"time"

	gorm "github.com/jinzhu/gorm"
	"github.com/renderedtext/go-watchman"
	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
)

func Run(db *gorm.DB) {
	for {
		time.Sleep(60 * time.Second)

		panicHandler(func() {
			Submit(db)
		})
	}
}

func Submit(db *gorm.DB) {
	count, err := models.RepositoryCount(db)
	if err != nil {
		return
	}

	stats, err := gitrekt.GetStats()
	if err != nil {
		return
	}

	_ = watchman.SubmitWithTags("gitrekt.Stats", []string{"TotalRepositoryCountInDB"}, count)
	_ = watchman.SubmitWithTags("gitrekt.Stats", []string{"TotalRepositoryCountOnDisk"}, stats.TotalRepositoryCount)
	_ = watchman.SubmitWithTags("gitrekt.Stats", []string{"TotalLockfileCount"}, stats.TotalLockfileCount)
	_ = watchman.SubmitWithTags("gitrekt.Stats", []string{"TotalQuarantinedCount"}, stats.TotalQuarantinedCount)
	_ = watchman.SubmitWithTags("gitrekt.Stats", []string{"TotalUnknownCount"}, stats.TotalUnknownCount)

	qstats, err := gitrekt.GetQuarantineStats()
	if err != nil {
		return
	}

	_ = watchman.SubmitWithTags("gitrekt.QuarantineStats", []string{"QuarantineReasonAuthTimeout"}, qstats.QuarantineReasonAuthTimeout)
	_ = watchman.SubmitWithTags("gitrekt.QuarantineStats", []string{"QuarantineReasonCloneTimeout"}, qstats.QuarantineReasonCloneTimeout)
	_ = watchman.SubmitWithTags("gitrekt.QuarantineStats", []string{"QuarantineReasonNotFound"}, qstats.QuarantineReasonNotFound)
	_ = watchman.SubmitWithTags("gitrekt.QuarantineStats", []string{"QuarantineReasonUnknown"}, qstats.QuarantineReasonUnknown)
}

func panicHandler(f func()) {
	defer func() {
		if p := recover(); p != nil {
			log.Println(p)
			log.Println(string(debug.Stack()))

			if flag.Lookup("test.v") != nil {
				panic(p)
			}
		}
	}()

	f()
}
