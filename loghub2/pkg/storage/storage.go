package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"

	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
)

type Storage interface {
	SaveFile(ctx context.Context, fileName, key string) error
	Exists(ctx context.Context, fileName string) (bool, error)
	ReadFile(ctx context.Context, fileName string) ([]byte, error)
	ReadFileAsReader(ctx context.Context, fileName string) (io.ReadCloser, error)
	DeleteFile(ctx context.Context, fileName string) error
}

func InitStorage() (Storage, error) {
	backend := os.Getenv("LOGS_STORAGE_BACKEND")
	if backend == "" {
		return nil, fmt.Errorf("no LOGS_STORAGE_BACKEND environment variable set")
	}

	switch backend {
	case "s3":
		s3Options := S3StorageOptions{
			Bucket:          utils.AssertEnvVar("S3_BUCKET_NAME"),
			URL:             os.Getenv("LOGS_STORAGE_S3_URL"),
			AccessKeyID:     os.Getenv("AWS_ACCESS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
			Region:          os.Getenv("AWS_REGION"),
		}
		return NewS3Storage(s3Options)
	case "gcs":
		gcsURL := os.Getenv("GCS_URL")
		if os.Getenv("GCS_URL") != "" {
			log.Printf("Creating gcs client pointing at %s", gcsURL)

			gcsBucket := utils.AssertEnvVar("GCS_BUCKET")

			var u, _ = url.Parse(gcsURL)
			var httpClient = &http.Client{Transport: RoundTripper(*u)}

			return NewGCSStorageWithClient(httpClient, gcsBucket)
		}

		gcsBucket := utils.AssertEnvVar("GCS_BUCKET")
		credsFile := utils.AssertEnvVar("GOOGLE_APPLICATION_CREDENTIALS")

		return NewGCSStorage(credsFile, gcsBucket)
	default:
		return nil, fmt.Errorf("cache backend '%s' is not available", backend)
	}
}
