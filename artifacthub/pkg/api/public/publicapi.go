package publicapi

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacts"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	ctxutil "github.com/semaphoreio/semaphore/artifacthub/pkg/util/context"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/retry"
	"go.uber.org/zap"
)

var (
	ErrArtifactNotFound = errors.New("artifact not found")
)

// signURL signs a given path with the given method, and returns it in a grpc encoded way.
func signURL(ctx context.Context, client storage.Client, artifact *models.Artifact, p, method string) (*artifacts.SignedURL, error) {
	url, err := client.SignURL(ctx, storage.SignURLOptions{
		BucketName:         artifact.BucketName,
		Method:             method,
		Path:               p,
		PathPrefix:         artifact.IdempotencyToken,
		IncludeContentType: false,
	})

	if err != nil {
		return nil, err
	}

	m := artifacts.SignedURL_Method(artifacts.SignedURL_Method_value[method])
	return &artifacts.SignedURL{URL: url, Method: m}, nil
}

// GenerateSignedURLPush creates signed URLs for pushing to the artifact storage.
func GenerateSignedURLPush(ctx context.Context, client storage.Client, artifact *models.Artifact, paths []string, force bool) ([]*artifacts.SignedURL, error) {
	count := len(paths)
	if !force {
		count *= 2
	}

	var err error
	urls := make([]*artifacts.SignedURL, count)
	j := 0
	for _, p := range paths {
		if !force {
			if urls[j], err = signURL(ctx, client, artifact, p, http.MethodHead); err != nil {
				return nil, err
			}
			j++
		}

		if urls[j], err = signURL(ctx, client, artifact, p, http.MethodPut); err != nil {
			return nil, err
		}

		j++
		log.Debug("PUT URL signed", zap.String("path", p), zap.Bool("force", force))
	}

	return urls, nil
}

func generateSignedURLsList(ctx context.Context, client storage.Client, artifact *models.Artifact, p, method string) ([]*artifacts.SignedURL, error) {
	bucket := client.GetBucket(storage.BucketOptions{
		Name:       artifact.BucketName,
		PathPrefix: artifact.IdempotencyToken,
	})

	isFile, err := bucket.IsFile(ctx, p)
	if err != nil {
		return nil, err
	}

	// Path points to a file, so we generate only one signed URL
	if isFile {
		urls := make([]*artifacts.SignedURL, 1)
		if urls[0], err = signURL(ctx, client, artifact, p, method); err != nil {
			return nil, err
		}
		return urls, nil
	}

	isDir, err := bucket.IsDir(ctx, p)
	if err != nil {
		return nil, err
	}

	// If the path does not point to a file nor a directory,
	// we generate no signed URLs and return an error
	if !isDir {
		log.Warn(fmt.Sprintf("The path '%s' does not exist", p))
		return nil, ErrArtifactNotFound
	}

	// Path points to a directory, so we generate signed URLs
	// for all files inside that directory
	urls := make([]*artifacts.SignedURL, 0)
	err = retry.OnFailure(ctx, "Listing Bucket path", func() error {
		iterator, err := bucket.ListPath(storage.ListOptions{Path: p})
		if err != nil {
			return err
		}

		for !iterator.Done() {
			o, err := iterator.Next()
			if err == storage.ErrNoMoreObjects {
				break
			}

			if err != nil {
				return err
			}

			url, err := signURL(ctx, client, artifact, o.Path, method)
			if err != nil {
				return err
			}

			urls = append(urls, url)
		}

		return nil
	})

	return urls, err
}

// GenerateSignedURLsList wraps signing URLs list with error logging.
func GenerateSignedURLsList(ctx context.Context, client storage.Client, artifact *models.Artifact, p, method string) ([]*artifacts.SignedURL, error) {
	us, err := generateSignedURLsList(ctx, client, artifact, p, method)
	if err != nil {
		return nil, err
	}
	return us, nil
}

// GenerateSignedURLPull creates signed URLs for pulling from the artifact storage.
func GenerateSignedURLPull(ctx context.Context, client storage.Client, artifact *models.Artifact, p string) ([]*artifacts.SignedURL, error) {
	l := ctxutil.Logger(ctx)
	l.Debug("GenerateSignedURLPull", zap.String("path", p))
	return GenerateSignedURLsList(ctx, client, artifact, p, http.MethodGet)
}

// GenerateSignedURLYank creates signed URLs for yanking from the artifact storage.
func GenerateSignedURLYank(ctx context.Context, client storage.Client, artifact *models.Artifact, p string) ([]*artifacts.SignedURL, error) {
	l := ctxutil.Logger(ctx)
	l.Debug("GenerateSignedURLYank", zap.String("path", p))
	return GenerateSignedURLsList(ctx, client, artifact, p, http.MethodDelete)
}
