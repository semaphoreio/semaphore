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

		require.NoError(t, PurgeArtifactContents(projectID, time.Now()))

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

		require.NoError(t, PurgeArtifactContents(projectID, time.Now()))

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

		require.NoError(t, PurgeArtifactContents(projectID, time.Now()))
		first, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		require.NotNil(t, first.PurgeRequestedAt)

		require.NoError(t, PurgeArtifactContents(projectID, time.Now()))
		second, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.Equal(t, *first.PurgeRequestedAt, *second.PurgeRequestedAt)
	})

	t.Run("a project with no storage is not an error", func(t *testing.T) {
		assert.NoError(t, PurgeArtifactContents(uuid.NewV4().String(), time.Now()))
	})
}

func Test__CancelArtifactPurge(t *testing.T) {
	models.PrepareDatabaseForTests()

	t.Run("takes the mark off a restored project's storage", func(t *testing.T) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("restore-bucket", projectID)
		require.NoError(t, err)

		require.NoError(t, PurgeArtifactContents(projectID, time.Now()))
		require.NoError(t, CancelArtifactPurge(projectID, time.Now()))

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
		require.NoError(t, CancelArtifactPurge(projectID, time.Now()))

		// Destruction follows the project being destroyed for good, which no restore
		// event can undo.
		stored, err := models.FindArtifactByID(artifact.ID.String())
		require.NoError(t, err)
		assert.NotNil(t, stored.DeletedAt)
		assert.True(t, stored.IsPurgeMarked())
	})

	t.Run("a project with no storage is not an error", func(t *testing.T) {
		assert.NoError(t, CancelArtifactPurge(uuid.NewV4().String(), time.Now()))
	})
}

// The two events arrive on separate queues, so either can be handled first. Times here
// are whole seconds apart, the precision the events are published with.
func Test__DeleteAndRestoreOrdering(t *testing.T) {
	models.PrepareDatabaseForTests()

	t0 := time.Now().UTC().Truncate(time.Second).Add(-time.Hour)

	storageFor := func(t *testing.T) (string, uuid.UUID) {
		projectID := uuid.NewV4().String()
		artifact, err := models.CreateArtifact("ordering-"+projectID, projectID)
		require.NoError(t, err)

		return projectID, artifact.ID
	}

	marked := func(t *testing.T, id uuid.UUID) bool {
		a, err := models.FindArtifactByID(id.String())
		require.NoError(t, err)

		return a.PurgeRequestedAt != nil
	}

	t.Run("a restore handled before its delete still wins", func(t *testing.T) {
		projectID, id := storageFor(t)

		require.NoError(t, CancelArtifactPurge(projectID, t0.Add(time.Second)))
		require.NoError(t, PurgeArtifactContents(projectID, t0))

		assert.False(t, marked(t, id))
	})

	t.Run("a delete then its restore, in order, leaves nothing marked", func(t *testing.T) {
		projectID, id := storageFor(t)

		require.NoError(t, PurgeArtifactContents(projectID, t0))
		require.NoError(t, CancelArtifactPurge(projectID, t0.Add(time.Second)))

		assert.False(t, marked(t, id))
	})

	t.Run("deleting again after a restore is honoured, whichever is handled first", func(t *testing.T) {
		inOrder, inOrderID := storageFor(t)
		require.NoError(t, CancelArtifactPurge(inOrder, t0))
		require.NoError(t, PurgeArtifactContents(inOrder, t0.Add(time.Second)))
		assert.True(t, marked(t, inOrderID))

		reversed, reversedID := storageFor(t)
		require.NoError(t, PurgeArtifactContents(reversed, t0.Add(time.Second)))
		require.NoError(t, CancelArtifactPurge(reversed, t0))
		assert.True(t, marked(t, reversedID))
	})

	t.Run("a delete and a restore in the same second resolve to the restore", func(t *testing.T) {
		deleteFirst, deleteFirstID := storageFor(t)
		require.NoError(t, PurgeArtifactContents(deleteFirst, t0))
		require.NoError(t, CancelArtifactPurge(deleteFirst, t0))
		assert.False(t, marked(t, deleteFirstID))

		restoreFirst, restoreFirstID := storageFor(t)
		require.NoError(t, CancelArtifactPurge(restoreFirst, t0))
		require.NoError(t, PurgeArtifactContents(restoreFirst, t0))
		assert.False(t, marked(t, restoreFirstID))
	})

	t.Run("a mark finer than the event times is cleared by a restore in its second", func(t *testing.T) {
		projectID, id := storageFor(t)

		a, err := models.FindArtifactByID(id.String())
		require.NoError(t, err)
		require.NoError(t, a.RequestPurge(db.Conn(), t0.Add(600*time.Millisecond)))

		require.NoError(t, CancelArtifactPurge(projectID, t0))

		assert.False(t, marked(t, id))
	})

	t.Run("an older restore redelivered late does not reopen the window", func(t *testing.T) {
		projectID, id := storageFor(t)

		require.NoError(t, CancelArtifactPurge(projectID, t0.Add(2*time.Second)))
		require.NoError(t, CancelArtifactPurge(projectID, t0))

		// This delete falls between the two restores, so the later restore still wins.
		require.NoError(t, PurgeArtifactContents(projectID, t0.Add(time.Second)))
		assert.False(t, marked(t, id))
	})
}
