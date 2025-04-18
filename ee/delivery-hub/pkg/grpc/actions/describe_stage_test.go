package actions

import (
	"context"
	"testing"

	uuid "github.com/google/uuid"
	protos "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"github.com/semaphoreio/semaphore/delivery-hub/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func Test__DescribeStage(t *testing.T) {
	r := support.SetupWithOptions(t, support.SetupOptions{Source: true, Stage: true})

	t.Run("canvas does not exist -> error", func(t *testing.T) {
		_, err := DescribeStage(context.Background(), &protos.DescribeStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       uuid.New().String(),
			Name:           r.Stage.Name,
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "canvas not found", s.Message())
	})

	t.Run("no name and no ID -> error", func(t *testing.T) {
		_, err := DescribeStage(context.Background(), &protos.DescribeStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.InvalidArgument, s.Code())
		assert.Equal(t, "must specify one of: id or name", s.Message())
	})

	t.Run("stage does not exist -> error", func(t *testing.T) {
		_, err := DescribeStage(context.Background(), &protos.DescribeStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           "does-not-exist",
		})

		s, ok := status.FromError(err)
		assert.True(t, ok)
		assert.Equal(t, codes.NotFound, s.Code())
		assert.Equal(t, "stage not found", s.Message())
	})

	t.Run("with name", func(t *testing.T) {
		response, err := DescribeStage(context.Background(), &protos.DescribeStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Name:           r.Stage.Name,
		})

		require.NoError(t, err)
		require.Equal(t, r.Stage.Name, response.Stage.Name)
		require.Equal(t, r.Stage.ID.String(), response.Stage.Id)
		require.Equal(t, r.Canvas.ID.String(), response.Stage.CanvasId)
		require.Equal(t, r.Org.String(), response.Stage.OrganizationId)
		require.NotNil(t, response.Stage.CreatedAt)
		require.True(t, response.Stage.ApprovalRequired)
		require.NotNil(t, response.Stage.RunTemplate)
		require.Len(t, response.Stage.Connections, 0)
	})

	t.Run("with ID", func(t *testing.T) {
		response, err := DescribeStage(context.Background(), &protos.DescribeStageRequest{
			OrganizationId: r.Org.String(),
			CanvasId:       r.Canvas.ID.String(),
			Id:             r.Stage.ID.String(),
		})

		require.NoError(t, err)
		require.Equal(t, r.Stage.Name, response.Stage.Name)
		require.Equal(t, r.Stage.ID.String(), response.Stage.Id)
		require.Equal(t, r.Canvas.ID.String(), response.Stage.CanvasId)
		require.Equal(t, r.Org.String(), response.Stage.OrganizationId)
		require.NotNil(t, response.Stage.CreatedAt)
		require.True(t, response.Stage.ApprovalRequired)
		require.NotNil(t, response.Stage.RunTemplate)
		require.Len(t, response.Stage.Connections, 0)
	})
}
