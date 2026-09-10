package bucketcleaner

import (
	"context"
	"log"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"gorm.io/gorm"
)

type BatchCleaner struct {
	artifactBucket  *models.Artifact
	retentionPolicy *models.RetentionPolicy
	cleanRequest    *CleanRequest

	client storage.Client
	bucket storage.Bucket
	pager  storage.ObjectPager

	visitedObjectCount int
	deletedObjectCount int
	paginationEnded    bool
	artifactDeleted    bool
	pages              int
}

func NewBatchCleaner(c storage.Client, cleanRequest *CleanRequest, pages int) *BatchCleaner {
	return &BatchCleaner{
		client:             c,
		cleanRequest:       cleanRequest,
		visitedObjectCount: 0,
		deletedObjectCount: 0,
		paginationEnded:    false,
		pages:              pages,
	}
}

type CleaningResult struct {
	Done            bool
	PaginationToken string
}

// The Run operation is the main entrypoint for bucket cleaning
//
// It bootstraps the list object iterator, and starts up the cleaning process.
func (c *BatchCleaner) Run(tx *gorm.DB) (string, error) {
	_ = watchman.Increment("bucketcleaner.worker.cleaner_run")

	var err error

	err = c.loadRecords()
	if err != nil {
		return "", err
	}

	// A purge must not wait out the once-a-day cleaning window: the whole point is
	// to stop storing (and charging for) artifacts of a project that is already
	// deleted. It also needs no retention policy, since everything goes anyway.
	if !c.isPurging() {
		if c.retentionPolicy == nil {
			return "", nil
		}

		if c.retentionPolicy.IsCleanedInLast24Hours() {
			return "", ErrBucketAlreadyCleanedToday
		}
	}

	err = c.setupObjectPager()
	if err != nil {
		return "", err
	}

	nextPageToken, err := c.cleanup()
	if err != nil {
		return "", err
	}

	// If the artifact storage was deleted, there's nothing else to do.
	if c.artifactDeleted {
		return "", nil
	}

	// If no more pages are left to visit,
	// we mark the cleaning as done, as stop.
	if nextPageToken == "" {
		c.paginationEnded = true

		// A purge deletes every object it visits, so once we have walked the whole
		// bucket it is empty and the storage itself can go now, instead of waiting
		// for a later run to notice it is empty.
		if c.isPurging() {
			return "", c.destroyArtifact()
		}

		return "", c.saveThatCleaningIsDone(tx)
	}

	// If more pages are left to visit,
	// we update the scheduled_for_cleaning_at timestamp,
	// since a new clean request will be sent with the latest pagination token.
	return nextPageToken, c.updateScheduled(tx)
}

func (c *BatchCleaner) updateScheduled(tx *gorm.DB) error {
	return tx.Table("retention_policies").
		Where("artifact_id = ?", c.cleanRequest.ArtifactBucketID.String()).
		Update("scheduled_for_cleaning_at", gorm.Expr("now()")).
		Error
}

func (c *BatchCleaner) saveThatCleaningIsDone(tx *gorm.DB) error {
	now := time.Now()
	c.retentionPolicy.LastCleanedAt = &now

	return tx.Model(c.retentionPolicy).
		Update("last_cleaned_at", c.retentionPolicy.LastCleanedAt).
		Error
}

func (c *BatchCleaner) loadRecords() error {
	artifact, err := models.FindArtifactByID(c.cleanRequest.ArtifactBucketID.String())
	if err != nil {
		return err
	}
	c.artifactBucket = artifact

	retentionPolicy, err := models.FindRetentionPolicy(c.cleanRequest.ArtifactBucketID)
	if err != nil {
		// An artifact storage on its way out does not need a retention policy,
		// everything under it is deleted regardless of the rules.
		if c.isPurging() {
			c.retentionPolicy = nil
			return nil
		}

		return err
	}
	c.retentionPolicy = retentionPolicy

	return nil
}

// isPurging reports whether the whole artifact storage is being deleted, which
// happens when its project was deleted. Every object under it goes, no matter
// what the retention policy says.
func (c *BatchCleaner) isPurging() bool {
	return c.artifactBucket.IsMarkedForPurging()
}

func (c *BatchCleaner) setupObjectPager() error {
	c.bucket = c.client.GetBucket(storage.BucketOptions{
		Name:       c.artifactBucket.BucketName,
		PathPrefix: c.artifactBucket.IdempotencyToken,
	})

	pager, err := c.bucket.ListObjectsWithPagination(storage.ListOptions{
		Path:            "artifacts/",
		PaginationToken: c.cleanRequest.PaginationToken,
		MaxKeys:         1000,
	})

	if err != nil {
		log.Printf("failed to start iterating objects in the bucket, %s", err.Error())
		return err
	}

	c.pager = pager

	return nil
}

func (c *BatchCleaner) cleanup() (string, error) {
	var err error
	var token string

	for i := 0; i < c.pages; i++ {
		token, err = c.cleanupOnePage()
		if err != nil {
			return "", err
		}
		if token == "" {
			return "", nil
		}
	}

	return token, nil
}

func (c *BatchCleaner) destroyArtifact() error {
	log.Printf(
		"Bucket %s is empty, and artifact %s should be destroyed",
		c.artifactBucket.BucketName,
		c.artifactBucket.ID.String(),
	)

	options := storage.BucketOptions{
		Name:       c.artifactBucket.BucketName,
		PathPrefix: c.artifactBucket.IdempotencyToken,
	}

	ctx, cancelFunc := context.WithTimeout(context.Background(), time.Minute)
	defer cancelFunc()

	if err := c.client.DestroyBucket(ctx, options); err != nil {
		log.Printf("Error deleting bucket %s for %s: %v", c.artifactBucket.BucketName, c.artifactBucket.ID.String(), err)
		return err
	}

	if err := c.artifactBucket.Destroy(); err != nil {
		log.Printf("Error destroying artifact %s: %v", c.artifactBucket.ID.String(), err)
		return err
	}

	log.Printf("Artifact storage %s fully destroyed", c.artifactBucket.ID.String())
	c.artifactDeleted = true
	return nil
}

func (c *BatchCleaner) cleanupOnePage() (string, error) {
	_ = watchman.Increment("bucketcleaner.worker.page_visits")
	objects, nextPageToken, err := c.pager.NextPage()
	if err != nil {
		return "", err
	}

	// If the bucket is already empty, and it was marked for deletion, we delete it.
	if len(objects) == 0 && c.cleanRequest.PaginationToken == "" && c.artifactBucket.DeletedAt != nil {
		if err := c.destroyArtifact(); err != nil {
			return "", err
		}
	}

	_ = watchman.IncrementBy("bucketcleaner.worker.object_visits", len(objects))

	results := []string{}

	for _, object := range objects {
		c.visitedObjectCount++

		// When the storage itself is being purged everything goes, including
		// objects younger than the minimum retention age.
		if c.isPurging() || c.retentionPolicy.IsMatching(object.Path, *object.Age) {
			c.deletedObjectCount++
			results = append(results, object.Path)
		}
	}

	_ = watchman.IncrementBy("bucketcleaner.worker.delete_objects", len(results))
	err = c.bucket.DeleteObjects(results)
	if err != nil {
		return "", err
	}

	return nextPageToken, nil
}
