package privateapi

import (
	"context"
	"testing"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
)

func rulesForTest() models.RetentionPolicyRules {
	return models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/test-results/**/*", Age: 7 * 24 * 3600},
		},
	}
}

func Test__DestroyArtifact(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()

	t.Run("marks the storage for purging and leaves the retention policy alone", func(t *testing.T) {
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		assert.NoError(t, err)

		rules := rulesForTest()
		_, err = models.CreateRetentionPolicy(artifact.ID, rules, rules, rules)
		assert.NoError(t, err)

		assert.NoError(t, DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		reloaded, err := models.FindArtifactByID(artifact.ID.String())
		assert.NoError(t, err)
		assert.NotNil(t, reloaded.DeletedAt)

		// Rules the customer configured have to survive. Overwriting them used to
		// throw their configuration away, and kept deleting the artifacts of a
		// project that was later restored.
		policy, err := models.FindRetentionPolicy(artifact.ID)
		assert.NoError(t, err)
		assert.Equal(t, rules, policy.ProjectLevelPolicies)
		assert.Equal(t, rules, policy.WorkflowLevelPolicies)
		assert.Equal(t, rules, policy.JobLevelPolicies)

		// ... and the storage has to be due for cleaning right away.
		assert.Nil(t, policy.LastCleanedAt)
		assert.Nil(t, policy.ScheduledForCleaningAt)
	})

	t.Run("creates a policy row so a storage without one is still schedulable", func(t *testing.T) {
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		assert.NoError(t, err)

		assert.NoError(t, DestroyArtifact(context.TODO(), s, artifact.ID.String()))

		policy, err := models.FindRetentionPolicy(artifact.ID)
		assert.NoError(t, err)
		assert.Empty(t, policy.ProjectLevelPolicies.Rules)
	})

	t.Run("is a no-op when the storage is already marked for purging", func(t *testing.T) {
		artifact, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
		assert.NoError(t, err)

		assert.NoError(t, DestroyArtifact(context.TODO(), s, artifact.ID.String()))
		first, err := models.FindArtifactByID(artifact.ID.String())
		assert.NoError(t, err)

		assert.NoError(t, DestroyArtifact(context.TODO(), s, artifact.ID.String()))
		second, err := models.FindArtifactByID(artifact.ID.String())
		assert.NoError(t, err)

		assert.Equal(t, first.DeletedAt.Unix(), second.DeletedAt.Unix())
	})

	// The project cleaner still calls this when it hard-destroys a project, long
	// after the storage itself was purged and removed.
	t.Run("is a no-op when the storage is already gone", func(t *testing.T) {
		assert.NoError(t, DestroyArtifact(context.TODO(), s, uuid.NewV4().String()))
	})
}

func Test__CreateArtifact(t *testing.T) {
	models.PrepareDatabaseForTests()
	s := storage.NewInMemoryStorage()

	t.Run("revives a storage that was marked for purging", func(t *testing.T) {
		token := uuid.NewV4().String()

		created, err := CreateArtifact(context.TODO(), s, token)
		assert.NoError(t, err)
		assert.NoError(t, DestroyArtifact(context.TODO(), s, created.ID.String()))

		// This is what restoring a project does: it asks for the project's storage
		// again, and has to get a working one back rather than one the cleaners are
		// about to destroy.
		revived, err := CreateArtifact(context.TODO(), s, token)
		assert.NoError(t, err)
		assert.Equal(t, created.ID, revived.ID)
		assert.Nil(t, revived.DeletedAt)

		reloaded, err := models.FindArtifactByID(created.ID.String())
		assert.NoError(t, err)
		assert.Nil(t, reloaded.DeletedAt)
	})

	t.Run("returns the existing storage when it is healthy", func(t *testing.T) {
		token := uuid.NewV4().String()

		created, err := CreateArtifact(context.TODO(), s, token)
		assert.NoError(t, err)

		again, err := CreateArtifact(context.TODO(), s, token)
		assert.NoError(t, err)
		assert.Equal(t, created.ID, again.ID)
		assert.Nil(t, again.DeletedAt)
	})
}
