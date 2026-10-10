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

// oldestPurgeAgeSeconds is how long the oldest due purge or destruction has been
// overdue. It stays low while the cleaner keeps up, so alert on it (above an hour);
// storages still inside their grace period are waiting on purpose and not counted.
func oldestPurgeAgeSeconds() (int64, error) {
	var res sql.NullFloat64
	grace := postgresInterval(PurgeGracePeriod)

	err := db.Conn().
		Table("artifacts").
		Select(
			"COALESCE(MAX(EXTRACT(EPOCH FROM (now() - COALESCE(deleted_at, purge_requested_at + CAST(? AS interval))))), 0)",
			grace,
		).
		Where("deleted_at IS NOT NULL OR purge_requested_at < now() - CAST(? AS interval)", grace).
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
