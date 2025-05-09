package actions

import (
	"context"
	"testing"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Test__UpdateTagState(t *testing.T) {
	r := support.Setup(t)

	event := support.CreateStageEvent(t, r.Source, r.Stage)

	// create tags with different tag names
	require.NoError(t, models.UpdateStageEventTagStateInBulk(
		database.Conn(),
		event.ID,
		models.TagStateUnknown,
		map[string]string{
			"version": "v1",
			"sha":     "1234",
		},
	))

	// create tag with same name, but different value
	require.NoError(t, models.UpdateStageEventTagStateInBulk(
		database.Conn(),
		event.ID,
		models.TagStateUnknown,
		map[string]string{
			"version": "v2",
		},
	))

	t.Run("missing tag name", func(t *testing.T) {
		_, err := UpdateTagState(context.Background(), &delivery.UpdateTagStateRequest{
			Tag: &delivery.Tag{},
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "missing tag name or value")
	})

	t.Run("missing tag value", func(t *testing.T) {
		_, err := UpdateTagState(context.Background(), &delivery.UpdateTagStateRequest{
			Tag: &delivery.Tag{Name: "version"},
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Contains(t, s.Message(), "missing tag name or value")
	})

	t.Run("tag is marked as healthy", func(t *testing.T) {
		res, err := UpdateTagState(context.Background(), &delivery.UpdateTagStateRequest{
			Tag: &delivery.Tag{
				Name:  "version",
				Value: "v1",
				State: delivery.Tag_TAG_STATE_HEALTHY,
			},
		})

		require.NoError(t, err)
		require.NotNil(t, res)

		//
		// Verify tags with different name were not updated
		//
		tags, err := models.ListStageTags("sha", "", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "sha", tags[0].TagName)
		assert.Equal(t, "1234", tags[0].TagValue)
		assert.Equal(t, models.TagStateUnknown, tags[0].TagState)

		//
		// Verify tags with same name but different values were not updated
		//
		tags, err = models.ListStageTags("version", "v2", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "version", tags[0].TagName)
		assert.Equal(t, "v2", tags[0].TagValue)
		assert.Equal(t, models.TagStateUnknown, tags[0].TagState)

		//
		// Verify tags with same name and value were updated
		//
		tags, err = models.ListStageTags("version", "v1", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "version", tags[0].TagName)
		assert.Equal(t, "v1", tags[0].TagValue)
		assert.Equal(t, models.TagStateHealthy, tags[0].TagState)
	})

	t.Run("tag is marked as unhealthy", func(t *testing.T) {
		res, err := UpdateTagState(context.Background(), &delivery.UpdateTagStateRequest{
			Tag: &delivery.Tag{
				Name:  "version",
				Value: "v1",
				State: delivery.Tag_TAG_STATE_UNHEALTHY,
			},
		})

		require.NoError(t, err)
		require.NotNil(t, res)

		//
		// Verify tags with different name were not updated
		//
		tags, err := models.ListStageTags("sha", "", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "sha", tags[0].TagName)
		assert.Equal(t, "1234", tags[0].TagValue)
		assert.Equal(t, models.TagStateUnknown, tags[0].TagState)

		//
		// Verify tags with same name but different values were not updated
		//
		tags, err = models.ListStageTags("version", "v2", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "version", tags[0].TagName)
		assert.Equal(t, "v2", tags[0].TagValue)
		assert.Equal(t, models.TagStateUnknown, tags[0].TagState)

		//
		// Verify tags with same name and value were updated
		//
		tags, err = models.ListStageTags("version", "v1", []string{}, "", "")
		require.NoError(t, err)
		require.Len(t, tags, 1)
		assert.Equal(t, "version", tags[0].TagName)
		assert.Equal(t, "v1", tags[0].TagValue)
		assert.Equal(t, models.TagStateUnhealthy, tags[0].TagState)
	})
}
