package projectdeletion

import (
	"os"
	"testing"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/projecthub"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/proto"
)

func Test__SoftDeleteWorker(t *testing.T) {
	models.PrepareDatabaseForTests()

	worker, err := NewSoftDeleteWorker(os.Getenv("AMQP_URL"))
	require.NoError(t, err)

	worker.Start()
	defer worker.Stop()

	require.Eventually(t, func() bool { return worker.consumer.State == "listening" }, 5*time.Second, 200*time.Millisecond)

	t.Run("marks the storage of a deleted project for purging", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), projectID)
		require.NoError(t, err)

		publish(t, SoftDeletedRoutingKey, &projecthub.ProjectDeleted{ProjectId: projectID})

		assert.Eventually(t, func() bool {
			stored, err := models.FindArtifactByID(artifact.ID.String())

			return err == nil && stored.PurgeRequestedAt != nil
		}, 10*time.Second, 200*time.Millisecond)

		// Only the contents are going. The storage stays until the project is
		// destroyed for good, so a restore has somewhere to push to.
		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Nil(t, stored.DeletedAt)
	})

	t.Run("a project with no storage is acked, not retried forever", func(t *testing.T) {
		publish(t, SoftDeletedRoutingKey, &projecthub.ProjectDeleted{ProjectId: uuid.NewV4().String()})

		// Nothing to assert on the artifact side, so this checks the worker survives
		// the message and goes on handling the next one.
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), projectID)
		require.NoError(t, err)

		publish(t, SoftDeletedRoutingKey, &projecthub.ProjectDeleted{ProjectId: projectID})

		assert.Eventually(t, func() bool {
			stored, err := models.FindArtifactByID(artifact.ID.String())

			return err == nil && stored.PurgeRequestedAt != nil
		}, 10*time.Second, 200*time.Millisecond)
	})
}

func Test__RestoreWorker(t *testing.T) {
	models.PrepareDatabaseForTests()

	worker, err := NewRestoreWorker(os.Getenv("AMQP_URL"))
	require.NoError(t, err)

	worker.Start()
	defer worker.Stop()

	require.Eventually(t, func() bool { return worker.consumer.State == "listening" }, 5*time.Second, 200*time.Millisecond)

	t.Run("takes the mark off when the project comes back", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), projectID)
		require.NoError(t, err)

		require.NoError(t, artifact.RequestPurge(db.Conn(), time.Now()))

		publish(t, RestoredRoutingKey, &projecthub.ProjectRestored{ProjectId: projectID})

		assert.Eventually(t, func() bool {
			stored, err := models.FindArtifactByID(artifact.ID.String())

			return err == nil && stored.PurgeRequestedAt == nil
		}, 10*time.Second, 200*time.Millisecond)
	})
}

func publish(t *testing.T, routingKey string, event proto.Message) {
	body, err := proto.Marshal(event)
	require.NoError(t, err)

	require.NoError(t, tackle.PublishMessage(&tackle.PublishParams{
		AmqpURL:    os.Getenv("AMQP_URL"),
		Body:       body,
		Exchange:   ProjectExchange,
		RoutingKey: routingKey,
	}))
}
