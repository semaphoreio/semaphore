package storage

import (
	"context"
	"os"
	"testing"

	assert "github.com/stretchr/testify/assert"
)

const (
	S3BucketName = "s3-test"
)

var s3Storage, _ = NewS3Storage(S3StorageOptions{URL: "http://s3:9000/", Bucket: S3BucketName})

func Test__S3SavedFileCanBeRetrieved(t *testing.T) {
	err := s3Storage.CreateBucket(S3BucketName)
	assert.Nil(t, err)

	tempFile, _ := os.CreateTemp("", "*")
	tempFile.Write([]byte(TestContent))
	tempFile.Close()

	err = s3Storage.SaveFile(context.Background(), tempFile.Name(), TestJobID)
	assert.Nil(t, err)

	read, err := s3Storage.ReadFile(context.Background(), TestJobID)
	assert.Nil(t, err)
	assert.Equal(t, TestContent, string(read))

	err = s3Storage.DeleteBucket(S3BucketName)
	assert.Nil(t, err)
	os.Remove(tempFile.Name())
}

func Test__S3CannotReadFileIfFileDoesNotExist(t *testing.T) {
	err := s3Storage.CreateBucket(S3BucketName)
	assert.Nil(t, err)

	read, err := s3Storage.ReadFile(context.Background(), "this-file-does-not-exist")
	assert.NotNil(t, err)
	assert.Nil(t, read)

	err = s3Storage.DeleteBucket(S3BucketName)
	assert.Nil(t, err)
}
