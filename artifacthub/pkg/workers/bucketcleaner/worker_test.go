package bucketcleaner

import (
	"log"
	"os"
	"testing"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
)

func Test__Worker(t *testing.T) {
	models.PrepareDatabaseForTests()

	s := storage.NewInMemoryStorage()

	worker, err := NewWorker(os.Getenv("AMQP_URL"), s)
	assert.Nil(t, err)

	t.Run("it can boot up and shut down", func(t *testing.T) {
		worker.Start()
		assert.Eventually(t, func() bool { return worker.state() == "listening" }, 5*time.Second, 1*time.Second)

		worker.Stop()
		assert.Eventually(t, func() bool { return worker.state() == "not-listening" }, 5*time.Second, 1*time.Second)
	})

	t.Run("cleans up cleans up the associated bucket", func(t *testing.T) {
		worker.Start()
		defer worker.Stop()

		_, policy := createBucketWithRetentionPolicy(t)

		log.Printf("Publishing %s", policy.ArtifactID.String())

		req, err := NewCleanRequest(policy.ArtifactID.String())
		assert.Nil(t, err)

		body, err := req.ToJSON()
		assert.Nil(t, err)

		err = tackle.PublishMessage(&tackle.PublishParams{
			AmqpURL:    os.Getenv("AMQP_URL"),
			Body:       body,
			Exchange:   BucketCleanerExchange,
			RoutingKey: BucketCleanerRoutingKey,
		})

		assert.Nil(t, err)
		assert.Eventually(t, func() bool {
			policy.Reload()

			return policy.LastCleanedAt != nil
		}, 10*time.Second, 1*time.Second)
	})
}
