package privateapi

import (
	"context"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func Test__PurgeArtifactContents(t *testing.T) {
	models.PrepareDatabaseForTests()

	t.Run("marks the storage and makes it due for cleaning", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("test-bucket", projectID)
		require.NoError(t, err)

		require.NoError(t, PurgeArtifactContents(projectID))

		marked, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, marked.PurgeRequestedAt)

		// The storage stays: the project can still be restored.
		assert.Nil(t, marked.DeletedAt)

		// A policy row has to exist, or the cleaner's scheduler never visits this
		// artifact and the purge would never run. Projects that never configured
		// retention have no row until now.
		policy, err := models.FindRetentionPolicy(artifact.ID)
		require.NoError(t, err)
		assert.Empty(t, policy.ProjectLevelPolicies.Rules)
		assert.Nil(t, policy.LastCleanedAt)
		assert.Nil(t, policy.ScheduledForCleaningAt)
	})

	t.Run("brings a storage cleaned today forward again, keeping its rules", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("test-bucket-cleaned", projectID)
		require.NoError(t, err)

		rules := models.RetentionPolicyRules{
			Rules: []models.RetentionPolicyRuleItem{{Selector: "/*", Age: models.MinRetentionPolicyAge}},
		}
		policy, err := models.CreateRetentionPolicy(artifact.ID, rules, rules, rules)
		require.NoError(t, err)

		cleanedToday := time.Now()
		policy.LastCleanedAt = &cleanedToday
		require.NoError(t, db.Conn().Save(policy).Error)

		require.NoError(t, PurgeArtifactContents(projectID))

		// Otherwise the objects would sit there until tomorrow's pass.
		policy, err = models.FindRetentionPolicy(artifact.ID)
		require.NoError(t, err)
		assert.Nil(t, policy.LastCleanedAt)

		// And the configured rules are unchanged.
		assert.Equal(t, rules, policy.ProjectLevelPolicies)
	})

	t.Run("a redelivered event changes nothing", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("test-bucket-repeat", projectID)
		require.NoError(t, err)

		require.NoError(t, PurgeArtifactContents(projectID))
		first, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		require.NotNil(t, first.PurgeRequestedAt)

		require.NoError(t, PurgeArtifactContents(projectID))
		second, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Equal(t, *first.PurgeRequestedAt, *second.PurgeRequestedAt)
	})

	t.Run("a project with no storage is not an error", func(t *testing.T) {
		assert.NoError(t, PurgeArtifactContents(uuid.NewV4().String()))
	})
}

func Test__CancelArtifactPurge(t *testing.T) {
	models.PrepareDatabaseForTests()

	t.Run("takes the mark off a restored project's storage", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("restore-bucket", projectID)
		require.NoError(t, err)

		require.NoError(t, PurgeArtifactContents(projectID))
		require.NoError(t, CancelArtifactPurge(projectID))

		restored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Nil(t, restored.PurgeRequestedAt)
		assert.False(t, restored.IsPurgeMarked())
	})

	t.Run("leaves a storage that is being destroyed alone", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("destroyed-bucket", projectID)
		require.NoError(t, err)

		require.NoError(t, DestroyArtifact(context.TODO(), storage.NewInMemoryStorage(), artifact.ID.String()))
		require.NoError(t, CancelArtifactPurge(projectID))

		// Destruction follows the project being destroyed for good, which no restore
		// event can undo.
		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.DeletedAt)
		assert.True(t, stored.IsPurgeMarked())
	})

	t.Run("a project with no storage is not an error", func(t *testing.T) {
		assert.NoError(t, CancelArtifactPurge(uuid.NewV4().String()))
	})
}
