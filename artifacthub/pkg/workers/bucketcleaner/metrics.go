package bucketcleaner

import (
	"database/sql"

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

	oldestPurge, err := oldestPurgeAgeSeconds()
	if err == nil {
		_ = watchman.Submit("bucketcleaner.oldest_purge_age", int(oldestPurge))
	}
}

// oldestPurgeAgeSeconds is how long the longest outstanding emptying has been
// going on, and is the signal to alert on.
//
// A purge empties a storage and clears its own mark in one cleaner run, so this
// sits at zero normally and rises only while marked work is not getting done. That
// is the failure no other counter shows: nothing errors, the objects simply stay.
// Alert above an hour. Covers destruction too, which also leaves the bucket behind
// when it cannot finish.
func oldestPurgeAgeSeconds() (int64, error) {
	var res sql.NullFloat64

	err := db.Conn().
		Table("artifacts").
		Select("COALESCE(MAX(EXTRACT(EPOCH FROM (now() - COALESCE(purge_requested_at, deleted_at)))), 0)").
		Where("purge_requested_at IS NOT NULL OR deleted_at IS NOT NULL").
		Row().
		Scan(&res)

	if err != nil {
		return 0, err
	}

	return int64(res.Float64), nil
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
