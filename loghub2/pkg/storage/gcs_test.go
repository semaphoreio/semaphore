package storage

import (
	"context"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"testing"

	"github.com/google/uuid"
	assert "github.com/stretchr/testify/assert"
)

var (
	TestBucketName = "gcs-test"
	TestProjectID  = uuid.NewString()
	TestJobID      = uuid.NewString()
	TestContent    = "line1\nline2\nline3\nline4\n"
)

var u, _ = url.Parse("http://gcs:4443/")
var httpClient = &http.Client{Transport: RoundTripper(*u)}
var gcsStorage, _ = NewGCSStorageWithClient(httpClient, TestBucketName)

func Test__SavedFileCanBeRetrieved(t *testing.T) {
	err := gcsStorage.CreateBucket(TestBucketName, TestProjectID)
	assert.Nil(t, err)

	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte(TestContent))
	tempFile.Close()

	err = gcsStorage.SaveFile(context.Background(), tempFile.Name(), TestJobID)
	assert.Nil(t, err)

	read, err := gcsStorage.ReadFile(context.Background(), TestJobID)
	assert.Nil(t, err)
	assert.Equal(t, TestContent, string(read))

	err = gcsStorage.DeleteBucket(TestBucketName)
	assert.Nil(t, err)
	os.Remove(tempFile.Name())
}

func Test__CannotReadFileIfFileDoesNotExist(t *testing.T) {
	err := gcsStorage.CreateBucket(TestBucketName, TestProjectID)
	assert.Nil(t, err)

	read, err := gcsStorage.ReadFile(context.Background(), "this-file-does-not-exist")
	assert.NotNil(t, err)
	assert.Nil(t, read)

	err = gcsStorage.DeleteBucket(TestBucketName)
	assert.Nil(t, err)
}
