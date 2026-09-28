package publicapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__RespondWithJobPayload(t *testing.T) {
	t.Run("valid payload is served as equivalent JSON", func(t *testing.T) {
		payload := `{"id": "123", "commands": [{"directive": "echo <b>&amp;</b>"}], "env_vars": []}`
		w := httptest.NewRecorder()

		require.NoError(t, respondWithJobPayload(w, payload))
		assert.Equal(t, http.StatusOK, w.Code)
		assert.Equal(t, "application/json", w.Header().Get("Content-Type"))

		var expected, actual interface{}
		require.NoError(t, json.Unmarshal([]byte(payload), &expected))
		require.NoError(t, json.Unmarshal(w.Body.Bytes(), &actual))
		assert.Equal(t, expected, actual)
		assert.NotContains(t, w.Body.String(), "<b>")
	})

	t.Run("invalid payload returns an error and writes nothing", func(t *testing.T) {
		w := httptest.NewRecorder()

		assert.Error(t, respondWithJobPayload(w, `not json`))
		assert.Empty(t, w.Body.String())
		assert.Empty(t, w.Header().Get("Content-Type"))
	})
}
