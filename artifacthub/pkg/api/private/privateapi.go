package privateapi

import (
	"context"
	"errors"
	"time"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	pathutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/path"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/retry"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"gorm.io/gorm"
)

// CreateArtifact creates a new artifact with a bucket, service account. If the same idempotency token
// has already entered to the database, it returns that row instead of creating a new one.
func CreateArtifact(ctx context.Context, client storage.Client, idempotencyToken string) (*models.Artifact, error) {
	a, err := models.FindArtifactByIdempotencyToken(idempotencyToken)
	if err == nil { // created already
		return a, nil
	}

	bucketName, err := client.CreateBucket(ctx)
	if err != nil {
		// don't care about any error
		_ = client.DestroyBucket(ctx, storage.BucketOptions{Name: bucketName})
		return nil, err
	}

	return models.CreateArtifact(bucketName, idempotencyToken)
}

// DestroyArtifact marks an artifact so the bucket cleaners empty it and then remove
// the storage itself.
//
// Buckets can hold more files than one request can delete, so the work is
// asynchronous: the mark is enough. This used to overwrite all three retention
// policies with a delete-everything rule to express it, which threw away the rules
// the project had configured and kept deleting a restored project's new artifacts.
func DestroyArtifact(ctx context.Context, client storage.Client, artifactID string) error {
	return db.Conn().Transaction(func(tx *gorm.DB) error {
		a, err := models.FindArtifactByIDWithTx(tx, artifactID)
		if err != nil {
			return err
		}

		if err := a.UpdateDeleteAt(tx, time.Now()); err != nil {
			return err
		}

		if err := models.ScheduleForCleaningWithTx(tx, a.ID); err != nil {
			return err
		}

		log.Info("marked artifact storage for destruction", zap.Reflect("artifact", a))

		return nil
	})
}

// PurgeArtifactContents marks a project's storage to be emptied once the grace period
// after deletedAt is up. Only the contents go, so a restored project can push again.
// A restore at or after deletedAt wins, whichever of the two is handled first.
func PurgeArtifactContents(projectID string, deletedAt time.Time) error {
	return db.Conn().Transaction(func(tx *gorm.DB) error {
		a, err := models.FindArtifactByIdempotencyTokenForUpdate(tx, projectID)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				log.Info("no artifact storage for project, nothing to purge",
					zap.String("project_id", projectID))

				return nil
			}

			return log.ErrorCode(codes.Internal, "Finding Artifact row to purge", err)
		}

		// Re-marking would push the grace period back.
		if a.IsPurgeMarked() {
			return nil
		}

		if a.ProjectRestoredAt != nil && !deletedAt.After(*a.ProjectRestoredAt) {
			log.Info("ignoring a delete that is not newer than the project's restore",
				zap.String("project_id", projectID), zap.String("artifact_id", a.ID.String()))

			return nil
		}

		if err := a.RequestPurge(tx, deletedAt); err != nil {
			return err
		}

		if err := models.ScheduleForCleaningWithTx(tx, a.ID); err != nil {
			return err
		}

		log.Info("marked artifact storage for purging",
			zap.String("project_id", projectID), zap.String("artifact_id", a.ID.String()))

		return nil
	})
}

// CancelArtifactPurge records the restore even when nothing is marked yet, so a delete
// handled after it is ignored, and clears any mark left by a delete that is not newer.
func CancelArtifactPurge(projectID string, restoredAt time.Time) error {
	return db.Conn().Transaction(func(tx *gorm.DB) error {
		a, err := models.FindArtifactByIdempotencyTokenForUpdate(tx, projectID)
		if err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return nil
			}

			return log.ErrorCode(codes.Internal, "Finding Artifact row to restore", err)
		}

		if err := a.RecordProjectRestored(tx, restoredAt); err != nil {
			return err
		}

		// A mark can be finer than the whole-second event times, so compare to the second.
		if a.PurgeRequestedAt == nil || a.PurgeRequestedAt.Truncate(time.Second).After(restoredAt) {
			return nil
		}

		if err := a.ClearPurgeMark(tx); err != nil {
			return err
		}

		log.Info("stopped purging artifact storage, its project was restored",
			zap.String("project_id", projectID), zap.String("artifact_id", a.ID.String()))

		return nil
	})
}

// DeleteTransferPath deletes an object or directory in the given Transfer.
func DeleteTransferPath(ctx context.Context, client storage.Client, artifact *models.Artifact, path string) error {
	ctx, _ = ctxutil.SetBucketName(ctx, artifact.BucketName)
	bucket := client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	err := bucket.DeletePath(ctx, path)
	if err == nil {
		log.Debug("deleted", zap.String("path", path))
	}

	return err
}

// DeleteArtifactPath deletes an object or directory in the given Artifact's bucket given by its ID.
func DeleteArtifactPath(ctx context.Context, client storage.Client, artifactID, path string) error {
	a, err := models.FindArtifactByID(artifactID)
	if err != nil {
		return err
	}

	ctx, _ = ctxutil.SetBucketName(ctx, a.BucketName)
	return DeleteTransferPath(ctx, client, a, path)
}

// ListTransferPath returns bucket contents for a given directory prefix, and transfer type.
func ListTransferPath(ctx context.Context, client storage.Client, artifact *models.Artifact, path string, wrapDirectories bool) ([]*artifacthub.ListItem, error) {
	bucket := client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	result := make([]*artifacthub.ListItem, 0)

	err := retry.OnFailure(ctx, "Listing Bucket path", func() error {
		iterator, err := bucket.ListPath(storage.ListOptions{Path: path, WrapSubDirectories: wrapDirectories})
		if err != nil {
			return err
		}

		for !iterator.Done() {
			item, err := iterator.Next()
			if err == storage.ErrNoMoreObjects {
				break
			}

			if err != nil {
				return err
			}

			result = append(result, &artifacthub.ListItem{Name: item.Path, IsDirectory: item.IsDirectory, Size: item.Size})
		}

		return nil
	})

	return result, err
}

// CountTransferPath returns bucket file count for a given directory prefix, and transfer type.
func CountTransferPath(ctx context.Context, client storage.Client, artifact *models.Artifact, path string) (int, error) {
	bucket := client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	var result int

	err := retry.OnFailure(ctx, "Listing Bucket path", func() error {
		result = 0 // retry

		iterator, err := bucket.ListPath(storage.ListOptions{Path: path})
		if err != nil {
			return err
		}

		count, err := iterator.Count()
		if err != nil {
			return err
		}

		result = count
		return nil
	})

	return result, err
}

// CountCategoryPath returns bucket file count for a given category level
// eg. project/<projectID> on the GCS.
func CountCategoryPath(ctx context.Context, client storage.Client, category artifacthub.CountArtifactsRequest_Category, categoryID, artifactID string) (int, error) {
	a, err := models.FindArtifactByID(artifactID)
	if err != nil {
		return 0, err
	}

	ctx, _ = ctxutil.SetBucketName(ctx, a.BucketName)
	p := pathutil.CategoryPath(category, categoryID)
	return CountTransferPath(ctx, client, a, p)
}

// ListArtifactPath returns bucket contents for a given directory prefix.
func ListArtifactPath(ctx context.Context, client storage.Client, artifactID, p string, wrapDirectories bool) ([]*artifacthub.ListItem, error) {
	a, err := models.FindArtifactByID(artifactID)
	if err != nil {
		return nil, err
	}

	ctx, _ = ctxutil.SetBucketName(ctx, a.BucketName)
	return ListTransferPath(ctx, client, a, p, wrapDirectories)
}

func GetSignedURL(ctx context.Context, client storage.Client, artifactID, p, m string) (string, error) {
	a, err := models.FindArtifactByID(artifactID)
	if err != nil {
		return "", err
	}

	method := "GET"
	if m != "" {
		method = m
	}

	return client.SignURL(ctx, storage.SignURLOptions{
		BucketName:         a.BucketName,
		Method:             method,
		Path:               p,
		PathPrefix:         a.IdempotencyToken,
		IncludeContentType: true,
	})
}
