package bucketcleaner

import (
	"testing"

	uuid "github.com/satori/go.uuid"
	"github.com/stretchr/testify/assert"
)

func TestCleanRequest(t *testing.T) {
	id := uuid.NewV4().String()

	t.Run("parsing clean requests", func(t *testing.T) {
		raw := `{"artifact_bucket_id": "` + id + `", "pagination_token": "token-content"}`

		req, err := ParseCleanRequest([]byte(raw))

		assert.Nil(t, err)
		assert.NotNil(t, req)

		assert.Equal(t, req.ArtifactBucketID.String(), id)
		assert.Equal(t, req.PaginationToken, "token-content")
	})

	t.Run("marshaling clean request", func(t *testing.T) {
		req, err := NewCleanRequest(id)
		assert.Nil(t, err)

		req.SetToken("token-content")

		msg, err := req.ToJSON()

		assert.Nil(t, err)
		assert.Equal(t, msg, []byte(`{"artifact_bucket_id":"`+id+`","pagination_token":"token-content"}`))
	})
}
