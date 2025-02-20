package storage

import (
	"context"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
)

type SeedObject struct {
	Name    string
	Content string
}

var storageBackends = map[string]func() (Client, error){
	"gcs": func() (Client, error) {
		return NewGcsClient("")
	},
	"s3": func() (Client, error) {
		return NewS3Client(S3Options{
			URL:             os.Getenv("ARTIFACT_STORAGE_S3_URL"),
			BucketName:      os.Getenv("ARTIFACT_STORAGE_S3_BUCKET"),
			AccessKeyID:     os.Getenv("AWS_ACCESS_KEY_ID"),
			SecretAccessKey: os.Getenv("AWS_SECRET_ACCESS_KEY"),
			Region:          os.Getenv("AWS_REGION"),
		})
	},
}

func RunTestForAllBackends(t *testing.T, test func(string, Client)) {
	for backend, provider := range storageBackends {
		client, err := provider()
		assert.Nil(t, err)
		test(backend, client)
	}
}

func SeedBucket(bucket Bucket, seedObjects []SeedObject) error {
	err := bucket.DeleteDir(context.Background(), "")
	if err != nil {
		return err
	}

	for _, object := range seedObjects {
		err := bucket.CreateObject(context.TODO(), object.Name, []byte(object.Content))
		if err != nil {
			return err
		}
	}

	return nil
}
