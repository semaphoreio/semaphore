package bucketcleaner

import (
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
)

//
// Shared utilities for testing the bucketcleaner package.
//

func changeScheduledForCleaningAtTimestamp(t *testing.T, policy *models.RetentionPolicy, byDurationFromNow time.Duration) {
	timestamp := time.Now().Add(byDurationFromNow)
	policy.ScheduledForCleaningAt = &timestamp

	err := db.Conn().Save(policy).Error
	assert.Nil(t, err)
	assert.NotNil(t, policy.ScheduledForCleaningAt)
}

func createBucketWithRetentionPolicy(t *testing.T) (*models.Artifact, *models.RetentionPolicy) {
	bucket, err := models.CreateArtifact(uuid.NewV4().String(), uuid.NewV4().String())
	assert.Nil(t, err)

	projectRules := models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/test-results/**/*", Age: 7 * 24 * 3600},
		},
	}

	workflowRules := models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/*", Age: 7 * 24 * 3600},
		},
	}

	jobRules := models.RetentionPolicyRules{
		Rules: []models.RetentionPolicyRuleItem{
			{Selector: "/*", Age: 7 * 24 * 3600},
		},
	}

	policy, err := models.CreateRetentionPolicy(bucket.ID, projectRules, workflowRules, jobRules)
	assert.Nil(t, err)

	return bucket, policy
}

func daysAgo(days int) time.Time {
	d := -24 * time.Hour * time.Duration(days)

	return time.Now().Add(d)
}
