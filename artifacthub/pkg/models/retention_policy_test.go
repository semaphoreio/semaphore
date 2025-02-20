package models

import (
	"fmt"
	"testing"
	"time"

	uuid "github.com/satori/go.uuid"
	"github.com/stretchr/testify/assert"
)

func Test__RetentionPoliciesModel(t *testing.T) {
	PrepareDatabaseForTests()

	a, err := CreateArtifact("testing-bucket", uuid.NewV4().String())
	assert.Nil(t, err)

	projectRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/test-results/**/*", Age: 7 * 24 * 3600},
		},
	}

	workflowRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/*", Age: 7 * 24 * 3600},
		},
	}

	jobRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/*", Age: 7 * 24 * 3600},
		},
	}

	t.Run("creating a retention policy", func(t *testing.T) {
		r, err := CreateRetentionPolicy(a.ID, projectRules, workflowRules, jobRules)
		assert.Nil(t, err)

		assert.Equal(t, r.ArtifactID, a.ID)

		assert.Equal(t, r.ProjectLevelPolicies.Rules[0].Selector, "/test-results/**/*")
		assert.Equal(t, r.ProjectLevelPolicies.Rules[0].Age, 7*24*3600)

		assert.Equal(t, r.WorkflowLevelPolicies.Rules[0].Selector, "/*")
		assert.Equal(t, r.WorkflowLevelPolicies.Rules[0].Age, 7*24*3600)

		assert.Equal(t, r.JobLevelPolicies.Rules[0].Selector, "/*")
		assert.Equal(t, r.JobLevelPolicies.Rules[0].Age, 7*24*3600)
	})

	t.Run("finding a retention policy", func(t *testing.T) {
		r, err := FindRetentionPolicy(a.ID)
		assert.Nil(t, err)

		assert.Equal(t, r.ProjectLevelPolicies.Rules[0].Selector, "/test-results/**/*")
	})

	t.Run("creating policy with too long selector", func(t *testing.T) {
		rules := RetentionPolicyRules{
			Rules: []RetentionPolicyRuleItem{
				{Selector: "/sdjhfalkjsdhfak;shdflkjahsdfkjahsdkfjhasjkdlfhalsjdhfalkjsdhfalksdhfkaljshdfklahdflkjahsdfklahdskfjahsdlkfahsdjlkfhasjdlkfa", Age: 7 * 24 * 3600},
			},
		}

		_, err := UpdateRetentionPolicy(a.ID, rules, workflowRules, jobRules)
		assert.NotNil(t, err)
		assert.Equal(t, "retention policy selector length must be less than 100 long", err.Error())
	})

	t.Run("creating policy with too many selector", func(t *testing.T) {
		rules := RetentionPolicyRules{
			Rules: []RetentionPolicyRuleItem{
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
				{Selector: "/**", Age: 7 * 24 * 3600},
			},
		}

		_, err := UpdateRetentionPolicy(a.ID, rules, workflowRules, jobRules)
		assert.NotNil(t, err)
		assert.Equal(t, "retention policy must have less than 10 rules", err.Error())
	})

	t.Run("creating policy with small age", func(t *testing.T) {
		rules := RetentionPolicyRules{
			Rules: []RetentionPolicyRuleItem{
				{Selector: "/**", Age: 12},
			},
		}

		_, err := UpdateRetentionPolicy(a.ID, rules, workflowRules, jobRules)
		assert.NotNil(t, err)
		assert.Equal(t, "retention policy age can't be shorter than a day", err.Error())
	})

	t.Run("if policy doesn't exists, update will create it", func(t *testing.T) {
		bucketWithNoPolicy, err := CreateArtifact("testing-bucket-2", uuid.NewV4().String())
		assert.Nil(t, err)

		rules := RetentionPolicyRules{
			Rules: []RetentionPolicyRuleItem{
				{Selector: "/**", Age: 7 * 24 * 3600},
			},
		}

		policy, err := UpdateRetentionPolicy(bucketWithNoPolicy.ID, rules, rules, rules)
		if assert.Nil(t, err) {
			assert.Equal(t, "/**", policy.ProjectLevelPolicies.Rules[0].Selector)
			assert.Equal(t, "/**", policy.WorkflowLevelPolicies.Rules[0].Selector)
			assert.Equal(t, "/**", policy.JobLevelPolicies.Rules[0].Selector)
		}
	})
}

func Test__RetentionPolicyMatching(t *testing.T) {
	PrepareDatabaseForTests()

	oneDay := 24 * 3600

	a, err := CreateArtifact("testing-bucket", uuid.NewV4().String())
	assert.Nil(t, err)

	projectRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/test-results/**/*", Age: 12 * oneDay},
			{Selector: "/**/*", Age: 7 * oneDay},
		},
	}

	workflowRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/*", Age: 4 * oneDay},
		},
	}

	jobRules := RetentionPolicyRules{
		Rules: []RetentionPolicyRuleItem{
			{Selector: "/job-examples/*", Age: 2 * oneDay},
		},
	}

	policy, err := CreateRetentionPolicy(a.ID, projectRules, workflowRules, jobRules)
	assert.Nil(t, err)

	// helper utilities
	daysAgo := func(d int) time.Duration { return time.Duration(d*24) * time.Hour }
	projectPath := func(path string) string { return fmt.Sprintf("artifacts/projects/%s%s", uuid.NewV4().String(), path) }
	workflowPath := func(path string) string { return fmt.Sprintf("artifacts/workflows/%s%s", uuid.NewV4().String(), path) }
	jobPath := func(path string) string { return fmt.Sprintf("artifacts/jobs/%s%s", uuid.NewV4().String(), path) }

	t.Run("it matches old objects from the project folder", func(t *testing.T) {
		assert.True(t, policy.IsMatching(projectPath("/release/v1.exe"), daysAgo(16)))
	})

	t.Run("it doesn't match new objects from the project folder", func(t *testing.T) {
		assert.False(t, policy.IsMatching(projectPath("/release/v1.exe"), daysAgo(2)))
	})

	t.Run("it stops after a first full match", func(t *testing.T) {
		assert.False(t, policy.IsMatching(projectPath("/test-results/a.txt"), daysAgo(8)))
		assert.True(t, policy.IsMatching(projectPath("/a/a.txt"), daysAgo(8)))
	})

	t.Run("it can match workflow paths", func(t *testing.T) {
		assert.True(t, policy.IsMatching(workflowPath("/test-results/a.txt"), daysAgo(8)))
		assert.False(t, policy.IsMatching(workflowPath("/test-results/a.txt"), daysAgo(2)))
	})

	t.Run("it can match job paths", func(t *testing.T) {
		assert.False(t, policy.IsMatching(jobPath("/hello/a.txt"), daysAgo(8)))
		assert.True(t, policy.IsMatching(jobPath("/job-examples/a.txt"), daysAgo(4)))
	})
}
