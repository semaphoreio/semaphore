package privateapi

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	artifacts "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacts"
	publicapi "github.com/semaphoreio/semaphore/artifacthub/pkg/api/public"
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

// MaxPathItems is the recommended per-request cap for MCP callers.
// Private API keeps limit <= 0 semantics as "no limit".
const MaxPathItems int32 = 1000

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

// ListTransferPath returns bucket contents for a given directory prefix and transfer type.
// This wrapper keeps backward compatibility for existing callers that do not pass a limit.
func ListTransferPath(ctx context.Context, client storage.Client, artifact *models.Artifact, path string, wrapDirectories bool) ([]*artifacthub.ListItem, error) {
	return listTransferPath(ctx, client, artifact, path, wrapDirectories, 0)
}

// ListTransferPathWithLimit returns bucket contents for a given directory prefix and transfer type,
// enforcing a hard maximum number of returned items when limit > 0.
func ListTransferPathWithLimit(ctx context.Context, client storage.Client, artifact *models.Artifact, path string, wrapDirectories bool, limit int) ([]*artifacthub.ListItem, error) {
	return listTransferPath(ctx, client, artifact, path, wrapDirectories, limit)
}

func listTransferPath(ctx context.Context, client storage.Client, artifact *models.Artifact, path string, wrapDirectories bool, limit int) ([]*artifacthub.ListItem, error) {
	bucket := client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	result := make([]*artifacthub.ListItem, 0)
	limitExceeded := false

	err := retry.OnFailure(ctx, "Listing Bucket path", func() error {
		attemptResult := make([]*artifacthub.ListItem, 0)
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

			if limit > 0 && len(attemptResult) >= limit {
				limitExceeded = true
				return nil
			}

			attemptResult = append(attemptResult, &artifacthub.ListItem{Name: item.Path, IsDirectory: item.IsDirectory, Size: item.Size})
		}

		if !limitExceeded {
			result = attemptResult
		}

		return nil
	})

	if limitExceeded {
		return nil, publicapi.ErrTooManyArtifacts
	}

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
func ListArtifactPath(ctx context.Context, client storage.Client, artifactID, p string, wrapDirectories bool, limit int32) ([]*artifacthub.ListItem, error) {
	a, err := models.FindArtifactByID(artifactID)
	if err != nil {
		return nil, err
	}

	ctx, _ = ctxutil.SetBucketName(ctx, a.BucketName)
	items, err := ListTransferPathWithLimit(ctx, client, a, p, wrapDirectories, normalizePathLimit(limit))
	if errors.Is(err, publicapi.ErrTooManyArtifacts) {
		return nil, log.ErrorCode(codes.FailedPrecondition, publicapi.ErrTooManyArtifacts.Error(), err)
	}

	return items, err
}

func GetSignedURL(ctx context.Context, client storage.Client, artifactID, p, m string) (string, error) {
	artifact, method, err := resolveArtifactAndMethod(artifactID, m)
	if err != nil {
		return "", err
	}

	return client.SignURL(ctx, storage.SignURLOptions{
		BucketName:         artifact.BucketName,
		Method:             method,
		Path:               p,
		PathPrefix:         artifact.IdempotencyToken,
		IncludeContentType: true,
	})
}

// GetSignedURLS returns one or more signed URLs for a file or a directory path.
// The generation logic is shared with the public artifact API (pull/yank directory behavior).
func GetSignedURLS(ctx context.Context, client storage.Client, artifactID, p, m string, limit int32) ([]*artifacthub.SignedURL, error) {
	artifact, method, err := resolveArtifactAndMethod(artifactID, m)
	if err != nil {
		return nil, err
	}

	signedURLs, err := publicapi.GenerateSignedURLsList(ctx, client, artifact, p, method, normalizePathLimit(limit))
	if err != nil {
		if errors.Is(err, publicapi.ErrArtifactNotFound) {
			return nil, log.ErrorCode(codes.NotFound, "artifact path not found", err)
		}

		if errors.Is(err, publicapi.ErrTooManyArtifacts) {
			return nil, log.ErrorCode(codes.FailedPrecondition, publicapi.ErrTooManyArtifacts.Error(), err)
		}

		return nil, err
	}

	return serializeSignedURLs(signedURLs), nil
}

func resolveArtifactAndMethod(artifactID, m string) (*models.Artifact, string, error) {
	artifact, err := models.FindArtifactByID(artifactID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", log.ErrorCode(codes.NotFound, "artifact store not found", err)
		}

		return nil, "", err
	}

	method := http.MethodGet
	if m != "" {
		method = m
	}

	return artifact, method, nil
}

func serializeSignedURLs(signedURLs []*artifacts.SignedURL) []*artifacthub.SignedURL {
	result := make([]*artifacthub.SignedURL, 0, len(signedURLs))
	for _, signedURL := range signedURLs {
		if signedURL == nil {
			continue
		}

		result = append(result, &artifacthub.SignedURL{
			Url:    signedURL.URL,
			Method: convertSignedURLMethod(signedURL.Method),
		})
	}

	return result
}

func convertSignedURLMethod(method artifacts.SignedURL_Method) artifacthub.SignedURL_Method {
	switch method {
	case artifacts.SignedURL_GET:
		return artifacthub.SignedURL_GET
	case artifacts.SignedURL_DELETE:
		return artifacthub.SignedURL_DELETE
	case artifacts.SignedURL_HEAD:
		return artifacthub.SignedURL_HEAD
	case artifacts.SignedURL_PUT:
		return artifacthub.SignedURL_PUT
	case artifacts.SignedURL_POST:
		return artifacthub.SignedURL_POST
	default:
		log.Warn(
			"unknown signed URL method from public API, defaulting to GET",
			zap.String("rpc", "GetSignedURLS"),
			zap.String("method", method.String()),
		)
		return artifacthub.SignedURL_GET
	}
}

func normalizePathLimit(limit int32) int {
	if limit <= 0 {
		return 0
	}
	if limit > MaxPathItems {
		return int(MaxPathItems)
	}

	return int(limit)
}
