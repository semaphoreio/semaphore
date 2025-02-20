package compression

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_GzipDecompressBigFile(t *testing.T) {
	var b bytes.Buffer
	gz := gzip.NewWriter(&b)
	_, err := gz.Write([]byte(`{"key": "value"}`))
	if err != nil {
		t.Fatal(err)
	}
	err = gz.Close()
	if err != nil {
		t.Fatal(err)
	}

	reader := bytes.NewBuffer(b.Bytes())
	decompressedReader, err := GzipDecompress(reader, 15)
	if err != nil {
		t.Fatal(err)
	}
	decoder := json.NewDecoder(decompressedReader)
	err = decoder.Decode(&struct{}{})
	assert.Error(t, err, "should not be nil")
}
