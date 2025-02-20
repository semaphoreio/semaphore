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
