package storage

import (
	"context"
	"fmt"
	"io/ioutil"
	"os"
	"testing"

	assert "github.com/stretchr/testify/assert"
)

func Test__GzippedDataCanBeReadWithGunzip(t *testing.T) {
	data := []byte("Testing compression")
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write(data)

	err := Gzip(context.Background(), tempFile.Name())
	assert.Nil(t, err)

	compressedFile, _ := ioutil.ReadFile(fmt.Sprintf("%s.gz", tempFile.Name()))
	decompressed, err := Gunzip(compressedFile)
	assert.Nil(t, err)

	assert.Equal(t, string(decompressed), string(data))
	os.Remove(tempFile.Name())
}

func Test__GzipRemovesOriginalFile(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name() + ".gz")

	err := Gzip(context.Background(), tempFile.Name())
	assert.Nil(t, err)

	_, err = os.Stat(tempFile.Name())
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(tempFile.Name() + ".gz")
	assert.Nil(t, err)
}

func Test__GzipFailsForMissingFile(t *testing.T) {
	fileName := fmt.Sprintf("%s/does-not-exist-%d", os.TempDir(), os.Getpid())

	err := Gzip(context.Background(), fileName)
	assert.NotNil(t, err)

	_, err = os.Stat(fileName + ".gz")
	assert.True(t, os.IsNotExist(err))
}

func Test__GzipDoesNotOverwriteExistingArchive(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name())

	existing := tempFile.Name() + ".gz"
	assert.Nil(t, ioutil.WriteFile(existing, []byte("existing"), 0600))
	defer os.Remove(existing)

	err := Gzip(context.Background(), tempFile.Name())
	assert.NotNil(t, err)

	// original input and pre-existing archive are both left untouched
	_, err = os.Stat(tempFile.Name())
	assert.Nil(t, err)
	content, _ := ioutil.ReadFile(existing)
	assert.Equal(t, "existing", string(content))
}

func Test__GzipFailsForCancelledContext(t *testing.T) {
	tempFile, _ := ioutil.TempFile("", "*")
	tempFile.Write([]byte("some logs"))
	tempFile.Close()
	defer os.Remove(tempFile.Name())

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	err := Gzip(ctx, tempFile.Name())
	assert.NotNil(t, err)

	_, err = os.Stat(tempFile.Name())
	assert.Nil(t, err)
}
