package bucketcleaner

import (
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
)

func SubmitMetrics() {
	notScheduled, err := notScheduledCount()
	if err == nil {
		_ = watchman.Submit("bucketcleaner.not_scheduled", int(notScheduled))
	}

	notCleaned, err := notCleanedCount()
	if err == nil {
		_ = watchman.Submit("bucketcleaner.not_cleaned", int(notCleaned))
	}

	total, err := totalCount()
	if err == nil {
		_ = watchman.Submit("bucketcleaner.total", int(total))
	}
}

func notScheduledCount() (int64, error) {
	var res int64

	err := db.Conn().
		Table("retention_policies").
		Where("scheduled_for_cleaning_at IS NULL or scheduled_for_cleaning_at < now() - interval '2 day'").
		Count(&res).
		Error

	return res, err
}

func notCleanedCount() (int64, error) {
	var res int64

	err := db.Conn().
		Table("retention_policies").
		Where("last_cleaned_at IS NULL or last_cleaned_at < now() - interval '2 day'").
		Count(&res).
		Error

	return res, err
}

func totalCount() (int64, error) {
	var res int64
	err := db.Conn().Table("retention_policies").Count(&res).Error

	return res, err
}
