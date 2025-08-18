package privateapi

import (
	"context"
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

// DestroyArtifact destroys an artifact by it's id and everything connected to it.
func DestroyArtifact(ctx context.Context, client storage.Client, artifactID string) error {
	// Since buckets may have more files than we can delete
	// before this request times out, we need to delete artifacts async.
	// For that, we use the built-in mechanism for applying retention policies.
	// Here, we update the retention policies used to
	// delete all objects that are older than the minimum age allowed (1 day),
	// and we will let the bucket cleaners do the work of deleting this artifact storage.
	rules := models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/**/*", Age: models.MinRetentionPolicyAge},
		},
	}

	return db.Conn().Transaction(func(tx *gorm.DB) error {
		a, err := models.FindArtifactByIDWithTx(tx, artifactID)
		if err != nil {
			return err
		}

		err = a.UpdateDeleteAt(tx, time.Now())
		if err != nil {
			return err
		}

		_, err = models.UpdateRetentionPolicyWithTx(tx, a.ID, rules, rules, rules)
		if err != nil {
			return err
		}

		log.Info("added retention policy for bucket destruction", zap.Reflect("artifact", a))
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
