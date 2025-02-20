package models

import (
	"fmt"
	"testing"
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/self_hosted"
	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	assert "github.com/stretchr/testify/assert"
	require "github.com/stretchr/testify/require"
	"gorm.io/gorm"
)

func Test__FindAgentType(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)

	at, err := FindAgentType(orgID, "s1-test-1")
	assert.Nil(t, err)

	assert.Equal(t, "s1-test-1", at.Name)
}

func Test__CreateAgentType(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	at, token, err := CreateAgentType(orgID, &requesterID, "s1-test-1")

	assert.Nil(t, err)
	assert.Equal(t, "s1-test-1", at.Name)
	assert.Len(t, token, 80)

	_, _, err = CreateAgentType(orgID, &requesterID, "s1-test-1")

	assert.NotNil(t, err)
	assert.Equal(t, "agent type name must by unique in the organization", err.Error())
}

func Test__DeleteAgentType(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("no agents => success", func(t *testing.T) {
		agentTypeName := "s1-test-1"
		agentType, _, err := CreateAgentType(orgID, &requesterID, agentTypeName)
		require.Nil(t, err)
		require.NoError(t, agentType.Delete())

		agentType, err = FindAgentType(orgID, agentTypeName)
		require.Nil(t, agentType)
		require.ErrorIs(t, err, gorm.ErrRecordNotFound)
	})

	t.Run("only registered agents => fails", func(t *testing.T) {
		agentTypeName := "s1-test-2"
		agentType, _, err := CreateAgentType(orgID, &requesterID, agentTypeName)
		require.Nil(t, err)

		// agent only registers
		_, _, err = RegisterAgent(orgID, agentTypeName, "hello1", AgentMetadata{})
		require.Nil(t, err)

		// agent type is not deleted
		require.ErrorIs(t, agentType.Delete(), ErrCantDeleteAgentTypeWithExistingAgents)
	})

	t.Run("only disconnected agents => success", func(t *testing.T) {
		agentTypeName := "s1-test-3"
		agentType, _, err := CreateAgentTypeWithSettings(orgID, &requesterID, agentTypeName, AgentNameSettings{
			ReleaseNameAfter: 60,
		})

		require.Nil(t, err)

		// agent registers and disconnects
		agent, _, err := RegisterAgent(orgID, agentTypeName, "hello3", AgentMetadata{})
		require.Nil(t, err)
		require.NoError(t, agent.Disconnect())

		// agent type is deleted, and agent is also deleted
		require.NoError(t, agentType.Delete())
		agent, err = FindAgentByName(orgID.String(), "hello3")
		require.Nil(t, agent)
		require.ErrorIs(t, err, gorm.ErrRecordNotFound)
	})

	t.Run("disconnected and registered agents => fails", func(t *testing.T) {
		agentTypeName := "s1-test-4"
		agentType, _, err := CreateAgentTypeWithSettings(orgID, &requesterID, agentTypeName, AgentNameSettings{
			ReleaseNameAfter: 60,
		})

		require.Nil(t, err)

		// one agent registers and disconnects
		// one agent only registers
		agent1, _, err := RegisterAgent(orgID, agentTypeName, "hello4", AgentMetadata{})
		require.Nil(t, err)
		require.NoError(t, agent1.Disconnect())
		_, _, err = RegisterAgent(orgID, agentTypeName, "hello5", AgentMetadata{})
		require.Nil(t, err)

		// agent type is not deleted
		require.ErrorIs(t, agentType.Delete(), ErrCantDeleteAgentTypeWithExistingAgents)

		// no agents are deleted either.
		agent, err := FindAgentByName(orgID.String(), "hello4")
		require.NoError(t, err)
		require.NotNil(t, agent)
		agent, err = FindAgentByName(orgID.String(), "hello5")
		require.NoError(t, err)
		require.NotNil(t, agent)
	})
}

func Test__ListAgentTypes(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)

	_, _, err = CreateAgentType(orgID, &requesterID, "s1-test-2")
	assert.Nil(t, err)

	ats, err := ListAgentTypes(orgID)
	assert.Nil(t, err)

	assert.Len(t, ats, 2)
	assert.Equal(t, "s1-test-1", ats[0].Name)
	assert.Equal(t, "s1-test-2", ats[1].Name)
}

func Test__ListAgentTypesWithCursor(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)
	time.Sleep(10 * time.Millisecond)

	_, _, err = CreateAgentType(orgID, &requesterID, "s1-test-2")
	assert.Nil(t, err)

	ats, nextCursor, err := ListAgentTypesWithCursor(orgID, 1, "")
	assert.Nil(t, err)

	assert.Len(t, ats, 1)
	assert.Equal(t, "s1-test-1", ats[0].Name)

	ats, nextCursor, err = ListAgentTypesWithCursor(orgID, 1, nextCursor)
	assert.Nil(t, err)

	assert.Len(t, ats, 1)
	assert.Equal(t, "s1-test-2", ats[0].Name)
	assert.Empty(t, nextCursor)
}

func Test__NewAgentNameSettings(t *testing.T) {
	t.Run("invalid release after", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			ReleaseAfter:     -120,
		})

		assert.ErrorContains(t, err, "name release hold must be 0 or greater than 60")

		_, err = NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			ReleaseAfter:     15,
		})

		assert.ErrorContains(t, err, "name release hold must be greater than 60")
	})

	t.Run("no aws account", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS,
			Aws: &self_hosted.AgentNameSettings_AWS{
				RoleNamePatterns: "role1",
			},
		})

		assert.ErrorContains(t, err, "AWS account cannot be empty")
	})

	t.Run("no aws role patterns", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS,
			Aws: &self_hosted.AgentNameSettings_AWS{
				AccountId: "1234124",
			},
		})

		assert.ErrorContains(t, err, "AWS role name patterns cannot be empty")
	})

	t.Run("aws info is not needed if origin is agent", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			Aws:              &self_hosted.AgentNameSettings_AWS{},
		})

		assert.NoError(t, err)
	})

	t.Run("aws account ID is not allowed if origin is agent", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			Aws: &self_hosted.AgentNameSettings_AWS{
				AccountId: "1234567890",
			},
		})

		assert.ErrorContains(t, err, "AWS account ID is not allowed for ASSIGNMENT_ORIGIN_AGENT")
	})

	t.Run("aws roles are not allowed if origin is agent", func(t *testing.T) {
		_, err := NewAgentNameSettings(&self_hosted.AgentNameSettings{
			AssignmentOrigin: self_hosted.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
			Aws: &self_hosted.AgentNameSettings_AWS{
				RoleNamePatterns: "role1,role2",
			},
		})

		assert.ErrorContains(t, err, "AWS role name patterns are not allowed for ASSIGNMENT_ORIGIN_AGENT")
	})
}

func Test__FindAgentTypeByToken(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, token, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)

	at, err := FindAgentTypeByToken(orgID.String(), securetoken.Hash(token))
	assert.Nil(t, err)
	assert.NotNil(t, at)
}

func Test__FindAgentTypeWithAgentCount(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	assert.Nil(t, err)

	result, err := FindAgentTypeWithAgentCount(orgID, "s1-test-1")
	assert.Nil(t, err)

	assert.Equal(t, result.TotalAgentCount, 1)
	assert.Equal(t, result.AgentType.Name, "s1-test-1")
}

func Test__ListAgentTypesWithAgentCount(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)

	_, _, err = CreateAgentType(orgID, &requesterID, "s1-test-2")
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello2", AgentMetadata{})
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-2", "hello3", AgentMetadata{})
	assert.Nil(t, err)

	result, err := ListAgentTypesWithAgentCount(orgID)
	assert.Nil(t, err)

	assert.Equal(t, result[0].AgentType.Name, "s1-test-1")
	assert.Equal(t, result[0].TotalAgentCount, 2)

	assert.Equal(t, result[1].AgentType.Name, "s1-test-2")
	assert.Equal(t, result[1].TotalAgentCount, 1)
}

func Test__ListCursorAgentTypesWithAgentCount(t *testing.T) {
	database.TruncateTables()

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := CreateAgentType(orgID, &requesterID, "s1-test-1")
	assert.Nil(t, err)
	time.Sleep(10 * time.Millisecond)

	last, _, err := CreateAgentType(orgID, &requesterID, "s1-test-2")
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello1", AgentMetadata{})
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-1", "hello2", AgentMetadata{})
	assert.Nil(t, err)

	_, _, err = RegisterAgent(orgID, "s1-test-2", "hello3", AgentMetadata{})
	assert.Nil(t, err)

	result, nextCursor, err := ListCursorAgentTypesWithAgentCount(orgID, 1, "")
	assert.Nil(t, err)

	assert.Equal(t, result[0].AgentType.Name, "s1-test-1")
	assert.Equal(t, result[0].TotalAgentCount, 2)
	assert.Equal(t, nextCursor, fmt.Sprintf("%d", last.CreatedAt.UnixMilli()))

	result, nextCursor, err = ListCursorAgentTypesWithAgentCount(orgID, 1, nextCursor)
	assert.Nil(t, err)

	assert.Equal(t, result[0].AgentType.Name, "s1-test-2")
	assert.Equal(t, result[0].TotalAgentCount, 1)
	assert.Empty(t, nextCursor)
}
