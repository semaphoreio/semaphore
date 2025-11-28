package jobdeleter

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseMessage(t *testing.T) {
	t.Run("parses valid payload", func(t *testing.T) {
		body := []byte(`{"artifact_id":"abc","job_id":"job-123"}`)

		msg, err := ParseMessage(body)

		require.NoError(t, err)
		require.Equal(t, "abc", msg.ArtifactID)
		require.Equal(t, "job-123", msg.JobID)
	})

	t.Run("fails when artifact_id missing", func(t *testing.T) {
		body := []byte(`{"artifact_id":"","job_id":"job-123"}`)

		_, err := ParseMessage(body)

		require.Error(t, err)
	})

	t.Run("fails when job_id missing", func(t *testing.T) {
		body := []byte(`{"artifact_id":"abc","job_id":""}`)

		_, err := ParseMessage(body)

		require.Error(t, err)
	})

	t.Run("fails when payload invalid", func(t *testing.T) {
		body := []byte(`{invalid json}`)

		_, err := ParseMessage(body)

		require.Error(t, err)
	})
}
