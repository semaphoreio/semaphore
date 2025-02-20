package privateserver

import (
	"testing"
	"time"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func Test__MarshalingRetentionPolicyToModel(t *testing.T) {
	rules := []*artifacthub.RetentionPolicy_RetentionPolicyRule{
		{Selector: "test_results/**/*", Age: 7 * 24 * 3600},
		{Selector: "test_results2/**/*", Age: 10 * 24 * 3600},
	}

	marshaled := marshalRetentionPolicyRuleToModel(rules)

	assert.Equal(t, 2, len(marshaled.Rules))

	assert.Equal(t, "test_results/**/*", marshaled.Rules[0].Selector)
	assert.Equal(t, 7*24*3600, marshaled.Rules[0].Age)

	assert.Equal(t, "test_results2/**/*", marshaled.Rules[1].Selector)
	assert.Equal(t, 10*24*3600, marshaled.Rules[1].Age)
}

func Test__MarshalingRetentionPolicyToModelToApiModel(t *testing.T) {
	policy := models.RetentionPolicy{
		ProjectLevelPolicies: models.RetentionPolicyRules{
			Rules: []models.RetentionPolicyRuleItem{
				{Selector: "/test-results/**/*", Age: 7 * 24 * 3600},
				{Selector: "/test-results2/**/*", Age: 10 * 24 * 3600},
			},
		},
		WorkflowLevelPolicies: models.RetentionPolicyRules{
			Rules: []models.RetentionPolicyRuleItem{
				{Selector: "/aaa/**/*", Age: 12 * 24 * 3600},
				{Selector: "/aaa/**/*", Age: 30 * 24 * 3600},
			},
		},
		JobLevelPolicies: models.RetentionPolicyRules{
			Rules: []models.RetentionPolicyRuleItem{
				{Selector: "/bbb/**/*", Age: 12 * 24 * 3600},
				{Selector: "/bbb/**/*", Age: 45 * 24 * 3600},
			},
		},
	}

	t.Run("timestamps not set", func(t *testing.T) {
		marshaled, err := marshalRetentionPolicyModelToAPIModel(&policy)
		assert.Nil(t, err)
		assert.Nil(t, marshaled.LastCleanedAt)
		assert.Nil(t, marshaled.ScheduledForCleaningAt)
	})

	t.Run("timestamps set", func(t *testing.T) {
		now := time.Now()
		policy.LastCleanedAt = &now
		policy.ScheduledForCleaningAt = &now
		marshaled, err := marshalRetentionPolicyModelToAPIModel(&policy)
		assert.Nil(t, err)
		assert.Equal(t, marshaled.LastCleanedAt, timestamppb.New(now))
		assert.Equal(t, marshaled.ScheduledForCleaningAt, timestamppb.New(now))
	})

	t.Run("policies are properly marshaled", func(t *testing.T) {
		marshaled, err := marshalRetentionPolicyModelToAPIModel(&policy)
		assert.Nil(t, err)
		assert.Equal(t, 2, len(marshaled.ProjectLevelRetentionPolicies))
		assert.Equal(t, 2, len(marshaled.WorkflowLevelRetentionPolicies))
		assert.Equal(t, 2, len(marshaled.JobLevelRetentionPolicies))

		assert.Equal(t, "/test-results/**/*", marshaled.ProjectLevelRetentionPolicies[0].Selector)
		assert.Equal(t, "/test-results2/**/*", marshaled.ProjectLevelRetentionPolicies[1].Selector)
		assert.Equal(t, "/aaa/**/*", marshaled.WorkflowLevelRetentionPolicies[0].Selector)
		assert.Equal(t, "/aaa/**/*", marshaled.WorkflowLevelRetentionPolicies[1].Selector)
		assert.Equal(t, "/bbb/**/*", marshaled.JobLevelRetentionPolicies[0].Selector)
		assert.Equal(t, "/bbb/**/*", marshaled.JobLevelRetentionPolicies[1].Selector)

		assert.Equal(t, int64(7*24*3600), marshaled.ProjectLevelRetentionPolicies[0].Age)
		assert.Equal(t, int64(10*24*3600), marshaled.ProjectLevelRetentionPolicies[1].Age)
		assert.Equal(t, int64(12*24*3600), marshaled.WorkflowLevelRetentionPolicies[0].Age)
		assert.Equal(t, int64(30*24*3600), marshaled.WorkflowLevelRetentionPolicies[1].Age)
		assert.Equal(t, int64(12*24*3600), marshaled.JobLevelRetentionPolicies[0].Age)
		assert.Equal(t, int64(45*24*3600), marshaled.JobLevelRetentionPolicies[1].Age)
	})
}
