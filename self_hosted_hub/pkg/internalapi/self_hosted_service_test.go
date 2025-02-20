package internalapi

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	models "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/self_hosted"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	"github.com/semaphoreio/semaphore/self_hosted_hub/test/grpcmock"
	assert "github.com/stretchr/testify/assert"
	require "github.com/stretchr/testify/require"
)

func Test__Describe__WhenNoAgentTypeExists(t *testing.T) {
	database.TruncateTables()

	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()

	request := &pb.DescribeRequest{
		OrganizationId: orgID.String(),
		Name:           "s1-test-a",
	}

	_, err := service.Describe(context.Background(), request)
	require.NotNil(t, err)
	require.Equal(t, err.Error(), "rpc error: code = NotFound desc = agent type not found")
}

func Test__Describe__WhenAgentTypeExists(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-a")
	require.Nil(t, err)

	request := &pb.DescribeRequest{
		OrganizationId: orgID.String(),
		Name:           "s1-test-a",
	}

	now := time.Now()
	response, err := service.Describe(context.Background(), request)
	require.Nil(t, err)
	require.Equal(t, "s1-test-a", response.AgentType.Name)
	require.Equal(t, orgID.String(), response.AgentType.OrganizationId)
	require.WithinDuration(t, now, response.AgentType.CreatedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.AgentType.UpdatedAt.AsTime(), 200*time.Millisecond)
}

func Test__DescribeAgent__WhenNoAgentExists(t *testing.T) {
	database.TruncateTables()

	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()

	request := &pb.DescribeAgentRequest{
		OrganizationId: orgID.String(),
		Name:           "my-non-existent-agent",
	}

	_, err := service.DescribeAgent(context.Background(), request)
	require.NotNil(t, err)
	require.Equal(t, err.Error(), "rpc error: code = NotFound desc = agent not found")
}

func Test__DescribeAgent__WhenAgentExists(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-a")
	require.Nil(t, err)

	_, _, err = models.RegisterAgent(orgID, "s1-test-a", "hello1", models.AgentMetadata{
		OS:        "Ubuntu 19.04",
		Arch:      "x86_64",
		PID:       90,
		Hostname:  "boxbox",
		IPAddress: "193.1.2.102",
		UserAgent: "Semaphore Agent/v1.2.3",
	})

	require.Nil(t, err)

	request := &pb.DescribeAgentRequest{
		OrganizationId: orgID.String(),
		Name:           "hello1",
	}

	now := time.Now()
	response, err := service.DescribeAgent(context.Background(), request)
	require.Nil(t, err)
	require.Equal(t, "hello1", response.Agent.Name)
	require.Equal(t, "s1-test-a", response.Agent.TypeName)
	require.Equal(t, "Ubuntu 19.04", response.Agent.Os)
	require.Equal(t, "x86_64", response.Agent.Arch)
	require.Equal(t, "boxbox", response.Agent.Hostname)
	require.Equal(t, "193.1.2.102", response.Agent.IpAddress)
	require.Equal(t, pb.Agent_WAITING_FOR_JOB, response.Agent.State)
	require.WithinDuration(t, now, response.Agent.ConnectedAt.AsTime(), 200*time.Millisecond)
	require.False(t, response.Agent.Disabled)
	require.Nil(t, response.Agent.DisabledAt)
}

func Test__Create(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)
	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("requester ID is required", func(t *testing.T) {
		request := &pb.CreateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    "",
			Name:           "s1-test-1",
		}

		_, err := service.Create(context.Background(), request)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid UUID length")
	})

	t.Run("name already exists", func(t *testing.T) {
		name := "s1-test-1"

		_, _, err := models.CreateAgentType(orgID, &requesterID, name)
		require.Nil(t, err)

		request := &pb.CreateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           name,
		}

		_, err = service.Create(context.Background(), request)
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "rpc error: code = AlreadyExists desc = agent type name must by unique in the organization")
	})

	t.Run("name does not follow allowed regex", func(t *testing.T) {
		names := []string{
			"this-agent-type-name-does-not-start-with-s1",
			"this-agent-type-name-has-s1-in-it-but-not-at-the-start",
			"s1-has-bad-character-&",
			"s1-more-bad-characters-&%$#!",
			"s1-has space-in-the-middle",
		}

		for _, name := range names {
			request := &pb.CreateRequest{
				OrganizationId: orgID.String(),
				RequesterId:    requesterID.String(),
				Name:           name,
			}

			_, err := service.Create(context.Background(), request)
			require.NotNil(t, err)
			require.Equal(
				t, err.Error(),
				fmt.Sprintf("rpc error: code = InvalidArgument desc = The agent type name '%s' is invalid: must follow the pattern ^s1-[a-zA-Z0-9-_]+$", name),
			)
		}
	})

	t.Run("requires feature to be enabled", func(t *testing.T) {
		os.Setenv("SELF_HOSTED_QUOTAS", "disabled")
		quotaClient.Clear(orgID.String())

		request := &pb.CreateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           "s1-test-1",
		}

		_, err := service.Create(context.Background(), request)
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "rpc error: code = FailedPrecondition desc = self-hosted agents are not available for your organization")

		os.Setenv("SELF_HOSTED_QUOTAS", "")
		quotaClient.Clear(orgID.String())
	})

	t.Run("creates new agent type", func(t *testing.T) {
		name := "s1-test-2"

		request := &pb.CreateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           name,
		}

		response, err := service.Create(context.Background(), request)
		require.Nil(t, err)

		now := time.Now()
		require.Equal(t, orgID.String(), response.AgentType.OrganizationId)
		require.Equal(t, requesterID.String(), response.AgentType.RequesterId)
		require.Equal(t, response.AgentType.Name, name)
		require.Equal(t, response.AgentType.TotalAgentCount, int32(0))
		require.WithinDuration(t, now, response.AgentType.CreatedAt.AsTime(), 200*time.Millisecond)
		require.WithinDuration(t, now, response.AgentType.UpdatedAt.AsTime(), 200*time.Millisecond)
		require.NotNil(t, response.AgentRegistrationToken)
	})

	t.Run("name with trailing space is created with space trimmed", func(t *testing.T) {
		request := &pb.CreateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           "   s1-test-3    ",
		}

		response, err := service.Create(context.Background(), request)
		require.Nil(t, err)

		require.Equal(t, orgID.String(), response.AgentType.OrganizationId)
		require.Equal(t, requesterID.String(), response.AgentType.RequesterId)
		require.Equal(t, response.AgentType.Name, "s1-test-3")
		require.Equal(t, response.AgentType.TotalAgentCount, int32(0))
		require.NotNil(t, response.AgentRegistrationToken)
	})
}

func Test__Update(t *testing.T) {
	database.TruncateTables()
	grpcmock.Start()

	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)
	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("requester ID is required", func(t *testing.T) {
		request := &pb.UpdateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    "",
			Name:           "s1-test-1",
		}

		_, err := service.Update(context.Background(), request)
		require.Error(t, err)
		require.Contains(t, err.Error(), "invalid UUID length")
	})

	t.Run("agent type not found", func(t *testing.T) {
		request := &pb.UpdateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           "s1-not-found",
		}

		_, err := service.Update(context.Background(), request)
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "rpc error: code = NotFound desc = record not found")
	})

	t.Run("invalid new settings", func(t *testing.T) {
		name := "s1-first"
		_, _, err := models.CreateAgentType(orgID, &requesterID, name)
		require.NoError(t, err)

		request := &pb.UpdateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			Name:           name,
			AgentType: &pb.AgentType{
				OrganizationId: orgID.String(),
				Name:           name,
				AgentNameSettings: &pb.AgentNameSettings{
					AssignmentOrigin: pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT,
					ReleaseAfter:     15,
				},
			},
		}

		_, err = service.Update(context.Background(), request)
		require.Error(t, err)
		require.Equal(
			t, err.Error(),
			"rpc error: code = InvalidArgument desc = name release hold must be greater than 60",
		)
	})

	t.Run("updates settings", func(t *testing.T) {
		name := "s1-test-2"
		_, _, err := models.CreateAgentType(orgID, &requesterID, name)
		require.NoError(t, err)

		now := time.Now()
		newRequesterID := database.UUID()
		_, err = service.Update(context.Background(), &pb.UpdateRequest{
			OrganizationId: orgID.String(),
			RequesterId:    newRequesterID.String(),
			Name:           name,
			AgentType: &pb.AgentType{
				OrganizationId: orgID.String(),
				Name:           name,
				AgentNameSettings: &pb.AgentNameSettings{
					AssignmentOrigin: pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS,
					ReleaseAfter:     300,
					Aws: &pb.AgentNameSettings_AWS{
						AccountId:        "123456789",
						RoleNamePatterns: "role1,role2",
					},
				},
			},
		})

		require.NoError(t, err)

		agentType, err := models.FindAgentType(orgID, name)
		require.NoError(t, err)
		require.Equal(t, newRequesterID.String(), agentType.RequesterID.String())
		require.Equal(t, int64(300), agentType.ReleaseNameAfter)
		require.Equal(t, models.NameAssignmentOriginFromAWSSTS, agentType.NameAssignmentOrigin)
		require.Equal(t, "123456789", agentType.AWSAccount)
		require.Equal(t, "role1,role2", agentType.AWSRoleNamePatterns)
		require.WithinDuration(t, now, *agentType.UpdatedAt, 200*time.Millisecond)
	})
}

func Test__List(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, _, err = models.CreateAgentType(orgID, &requesterID, "s1-test-2")
	require.Nil(t, err)

	request := &pb.ListRequest{
		OrganizationId: orgID.String(),
	}

	now := time.Now()
	response, err := service.List(context.Background(), request)
	require.Nil(t, err)
	require.Len(t, response.AgentTypes, 2)
	require.Equal(t, response.AgentTypes[0].Name, "s1-test-1")
	require.Equal(t, response.AgentTypes[0].OrganizationId, orgID.String())
	require.Equal(t, response.AgentTypes[0].RequesterId, requesterID.String())
	require.Equal(t, response.AgentTypes[0].TotalAgentCount, int32(0))
	require.WithinDuration(t, now, response.AgentTypes[0].CreatedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.AgentTypes[0].UpdatedAt.AsTime(), 200*time.Millisecond)
	require.Equal(t, response.AgentTypes[1].Name, "s1-test-2")
	require.Equal(t, response.AgentTypes[1].OrganizationId, orgID.String())
	require.Equal(t, response.AgentTypes[1].RequesterId, requesterID.String())
	require.Equal(t, response.AgentTypes[1].TotalAgentCount, int32(0))
	require.WithinDuration(t, now, response.AgentTypes[1].CreatedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.AgentTypes[1].UpdatedAt.AsTime(), 200*time.Millisecond)
}

func Test__ListKeyset(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, _, err = models.CreateAgentType(orgID, &requesterID, "s1-test-2")
	require.Nil(t, err)

	_, _, err = models.CreateAgentType(orgID, &requesterID, "s1-test-3")
	require.Nil(t, err)

	request := &pb.ListKeysetRequest{
		OrganizationId: orgID.String(),
		PageSize:       2,
	}

	now := time.Now()
	response, err := service.ListKeyset(context.Background(), request)
	require.Nil(t, err)
	require.Len(t, response.AgentTypes, 2)
	require.Equal(t, response.AgentTypes[0].Name, "s1-test-1")
	require.Equal(t, response.AgentTypes[0].OrganizationId, orgID.String())
	require.Equal(t, response.AgentTypes[0].RequesterId, requesterID.String())
	require.Equal(t, response.AgentTypes[0].TotalAgentCount, int32(0))
	require.WithinDuration(t, now, response.AgentTypes[0].CreatedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.AgentTypes[0].UpdatedAt.AsTime(), 200*time.Millisecond)
	require.Equal(t, response.AgentTypes[1].Name, "s1-test-2")
	require.Equal(t, response.AgentTypes[1].OrganizationId, orgID.String())
	require.Equal(t, response.AgentTypes[1].RequesterId, requesterID.String())
	require.Equal(t, response.AgentTypes[1].TotalAgentCount, int32(0))
	require.WithinDuration(t, now, response.AgentTypes[1].CreatedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.AgentTypes[1].UpdatedAt.AsTime(), 200*time.Millisecond)
	require.NotNil(t, response.NextPageCursor)
}

func Test__ListAgents(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	_, _, err = models.RegisterAgent(orgID, "s1-test-1", "hello1", models.AgentMetadata{
		OS:        "Ubuntu 19.04",
		Arch:      "x86_64",
		PID:       90,
		Hostname:  "boxbox",
		IPAddress: "193.1.2.102",
		UserAgent: "Semaphore Agent/v1.2.3",
	})
	require.Nil(t, err)

	_, _, err = models.RegisterAgent(orgID, "s1-test-1", "hello2", models.AgentMetadata{
		OS:        "Ubuntu 19.04",
		Arch:      "x86_64",
		PID:       90,
		Hostname:  "boxbox",
		IPAddress: "193.1.2.102",
		UserAgent: "Semaphore Agent/v1.2.3",
	})
	require.Nil(t, err)

	_, err = models.DisableAgent(orgID, "s1-test-1", "hello2")
	require.Nil(t, err)

	request := &pb.ListAgentsRequest{
		OrganizationId: orgID.String(),
		AgentTypeName:  "s1-test-1",
	}

	response, err := service.ListAgents(context.Background(), request)
	require.Nil(t, err)
	require.Len(t, response.Agents, 2)
	require.Empty(t, response.Cursor)

	now := time.Now()
	require.Equal(t, response.Agents[0].Name, "hello1")
	require.Equal(t, response.Agents[0].Os, "Ubuntu 19.04")
	require.Equal(t, response.Agents[0].Pid, int32(90))
	require.Equal(t, response.Agents[0].Arch, "x86_64")
	require.Equal(t, response.Agents[0].Hostname, "boxbox")
	require.Equal(t, response.Agents[0].IpAddress, "193.1.2.102")
	require.Equal(t, response.Agents[0].UserAgent, "Semaphore Agent/v1.2.3")
	require.WithinDuration(t, now, response.Agents[0].ConnectedAt.AsTime(), 200*time.Millisecond)
	require.Nil(t, response.Agents[0].DisabledAt)

	require.Equal(t, response.Agents[1].Name, "hello2")
	require.Equal(t, response.Agents[1].Os, "Ubuntu 19.04")
	require.Equal(t, response.Agents[1].Pid, int32(90))
	require.Equal(t, response.Agents[1].Arch, "x86_64")
	require.Equal(t, response.Agents[1].Hostname, "boxbox")
	require.Equal(t, response.Agents[1].IpAddress, "193.1.2.102")
	require.Equal(t, response.Agents[1].UserAgent, "Semaphore Agent/v1.2.3")
	require.WithinDuration(t, now, response.Agents[1].ConnectedAt.AsTime(), 200*time.Millisecond)
	require.WithinDuration(t, now, response.Agents[1].DisabledAt.AsTime(), 200*time.Millisecond)
}

func Test__OccupyAgent(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)
	orgID := database.UUID()
	requesterID := database.UUID()

	_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
	require.Nil(t, err)

	t.Run("creates occupation request", func(t *testing.T) {
		jobID := database.UUID()
		request := &pb.OccupyAgentRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-1",
			JobId:          jobID.String(),
		}

		response, err := service.OccupyAgent(context.Background(), request)
		require.Nil(t, err)
		require.Empty(t, response.AgentId)
		require.Empty(t, response.AgentName)

		req, err := models.FindOccupationRequest(orgID, "s1-test-1", jobID)
		require.NoError(t, err)
		require.Equal(t, orgID, req.OrganizationID)
		require.Equal(t, "s1-test-1", req.AgentTypeName)
		require.Equal(t, jobID, req.JobID)
	})
}

func Test__ReleaseAgent(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("agent is properly released", func(t *testing.T) {
		_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
		require.Nil(t, err)

		agent, token, err := models.RegisterAgent(orgID, "s1-test-1", "hello1", models.AgentMetadata{})
		require.Nil(t, err)

		jobID, _ := models.ForcefullyOccupyAgentWithJobID(agent)
		request := &pb.ReleaseAgentRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-1",
			JobId:          jobID.String(),
		}

		_, err = service.ReleaseAgent(context.Background(), request)
		require.Nil(t, err)

		agent, err = models.FindAgentByToken(orgID.String(), securetoken.Hash(token))
		require.Nil(t, err)
		require.Nil(t, agent.AssignedJobID)
	})

	t.Run("no error when trying to release an agent that wasn't occupied or doesn't exist anymore", func(t *testing.T) {
		_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-2")
		require.Nil(t, err)

		_, _, err = models.RegisterAgent(orgID, "s1-test-2", "hello2", models.AgentMetadata{})
		require.Nil(t, err)

		jobID := database.UUID()
		request := &pb.ReleaseAgentRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-2",
			JobId:          jobID.String(),
		}

		_, err = service.ReleaseAgent(context.Background(), request)
		require.Nil(t, err)
	})
}

func Test__DeleteAgentType(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("agent type not found", func(t *testing.T) {
		request := &pb.DeleteAgentTypeRequest{
			OrganizationId: orgID.String(),
			Name:           "s1-test-not-existing",
		}

		_, err := service.DeleteAgentType(context.Background(), request)
		require.NotNil(t, err)

		require.Equal(t, err.Error(), "rpc error: code = NotFound desc = agent type not found")
	})

	t.Run("agent type has no agents", func(t *testing.T) {
		_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
		require.Nil(t, err)

		request := &pb.DeleteAgentTypeRequest{
			OrganizationId: orgID.String(),
			Name:           "s1-test-1",
		}

		_, err = service.DeleteAgentType(context.Background(), request)
		require.Nil(t, err)

		_, err = models.FindAgentType(orgID, "s1-test-1")
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "record not found")
	})

	t.Run("agent type has associated agents", func(t *testing.T) {
		_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-2")
		require.Nil(t, err)

		_, _, err = models.RegisterAgent(orgID, "s1-test-2", "hello1", models.AgentMetadata{})
		require.Nil(t, err)

		request := &pb.DeleteAgentTypeRequest{
			OrganizationId: orgID.String(),
			Name:           "s1-test-2",
		}

		_, err = service.DeleteAgentType(context.Background(), request)
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "rpc error: code = FailedPrecondition desc = can't delete agent type with existing agents")

		_, err = models.FindAgentType(orgID, "s1-test-2")
		require.Nil(t, err)
	})
}

func Test__ResetToken(t *testing.T) {
	database.TruncateTables()

	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("agent type not found", func(t *testing.T) {
		request := &pb.ResetTokenRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			AgentType:      "s1-test-not-existing",
		}

		_, err := service.ResetToken(context.Background(), request)
		require.NotNil(t, err)

		require.Equal(t, err.Error(), "rpc error: code = NotFound desc = agent type not found")
	})

	t.Run("new token works, old token does not", func(t *testing.T) {
		_, firstToken, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
		require.Nil(t, err)

		_, err = models.FindAgentTypeByToken(orgID.String(), securetoken.Hash(firstToken))
		require.Nil(t, err)

		request := &pb.ResetTokenRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			AgentType:      "s1-test-1",
		}

		response, err := service.ResetToken(context.Background(), request)
		require.Nil(t, err)

		_, err = models.FindAgentTypeByToken(orgID.String(), securetoken.Hash(firstToken))
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "record not found")

		_, err = models.FindAgentTypeByToken(orgID.String(), securetoken.Hash(response.Token))
		require.Nil(t, err)
	})

	t.Run("agent type has associated agents", func(t *testing.T) {
		_, firstToken, err := models.CreateAgentType(orgID, &requesterID, "s1-test-2")
		require.Nil(t, err)

		_, _, err = models.RegisterAgent(orgID, "s1-test-2", "hello1", models.AgentMetadata{})
		require.Nil(t, err)

		request := &pb.ResetTokenRequest{
			OrganizationId: orgID.String(),
			RequesterId:    requesterID.String(),
			AgentType:      "s1-test-2",
		}

		response, err := service.ResetToken(context.Background(), request)
		require.Nil(t, err)

		_, err = models.FindAgentTypeByToken(orgID.String(), securetoken.Hash(firstToken))
		require.NotNil(t, err)
		require.Equal(t, err.Error(), "record not found")

		_, err = models.FindAgentTypeByToken(orgID.String(), securetoken.Hash(response.Token))
		require.Nil(t, err)
	})

	t.Run("does not disable agents", func(t *testing.T) {
		models.CreateAgentType(orgID, &requesterID, "s1-test-3")
		models.RegisterAgent(orgID, "s1-test-3", "test-3-001", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-3", "test-3-002", models.AgentMetadata{})

		request := &pb.ResetTokenRequest{
			OrganizationId:          orgID.String(),
			RequesterId:             requesterID.String(),
			AgentType:               "s1-test-3",
			DisconnectRunningAgents: false,
		}

		response, err := service.ResetToken(context.Background(), request)
		require.Nil(t, err)
		require.NotNil(t, response)

		agents, _, err := models.ListAgentsWithCursor(orgID, "s1-test-3", 100, "")
		require.Nil(t, err)

		if assert.Len(t, agents, 2) {
			assertDisabledAtIsNotSet(t, agents)
		}
	})

	t.Run("disables running agents", func(t *testing.T) {
		models.CreateAgentType(orgID, &requesterID, "s1-test-4")
		models.CreateAgentType(orgID, &requesterID, "s1-test-5")
		models.RegisterAgent(orgID, "s1-test-4", "test-4-001", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-4", "test-4-002", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-5", "test-5-001", models.AgentMetadata{})

		request := &pb.ResetTokenRequest{
			OrganizationId:          orgID.String(),
			RequesterId:             requesterID.String(),
			AgentType:               "s1-test-4",
			DisconnectRunningAgents: true,
		}

		response, err := service.ResetToken(context.Background(), request)
		require.Nil(t, err)
		require.NotNil(t, response)

		agents, _, err := models.ListAgentsWithCursor(orgID, "s1-test-5", 100, "")
		require.Nil(t, err)

		if assert.Len(t, agents, 1) {
			agent := agents[0]
			require.Nil(t, agent.DisabledAt)
		}

		agents, _, err = models.ListAgentsWithCursor(orgID, "s1-test-4", 100, "")
		require.Nil(t, err)

		if assert.Len(t, agents, 2) {
			assertDisabledAtIsSet(t, time.Now(), agents)
		}
	})
}

func Test__DisableAllAgents(t *testing.T) {
	database.TruncateTables()
	var featureHubProvider, _ = feature.NewFeatureHubProvider("0.0.0.0:50052")
	var quotaClient, _ = quotas.NewQuotaClient(featureHubProvider)
	service := NewSelfHostedService(quotaClient)

	orgID := database.UUID()
	requesterID := database.UUID()

	t.Run("no agents", func(t *testing.T) {
		_, _, err := models.CreateAgentType(orgID, &requesterID, "s1-test-1")
		require.Nil(t, err)

		_, err = service.DisableAllAgents(context.Background(), &pb.DisableAllAgentsRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-1",
		})

		require.Nil(t, err)
	})

	t.Run("only disables agents of proper agent type", func(t *testing.T) {
		models.CreateAgentType(orgID, &requesterID, "s1-test-2")
		models.CreateAgentType(orgID, &requesterID, "s1-test-3")
		models.RegisterAgent(orgID, "s1-test-2", "test-2-001", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-2", "test-2-002", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-3", "test-3-001", models.AgentMetadata{})

		request := &pb.DisableAllAgentsRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-2",
		}

		_, err := service.DisableAllAgents(context.Background(), request)
		require.Nil(t, err)

		agents, _, err := models.ListAgentsWithCursor(orgID, "s1-test-3", 100, "")
		require.Nil(t, err)

		if assert.Len(t, agents, 1) {
			assertDisabledAtIsNotSet(t, agents)
		}

		agents, _, err = models.ListAgentsWithCursor(orgID, "s1-test-2", 100, "")
		require.Nil(t, err)

		if assert.Len(t, agents, 2) {
			assertDisabledAtIsSet(t, time.Now(), agents)
		}
	})

	t.Run("only disables idle agents of proper agent type", func(t *testing.T) {
		models.CreateAgentType(orgID, &requesterID, "s1-test-4")
		models.CreateAgentType(orgID, &requesterID, "s1-test-5")
		models.RegisterAgent(orgID, "s1-test-4", "test-4-001", models.AgentMetadata{})
		models.RegisterAgent(orgID, "s1-test-4", "test-4-002", models.AgentMetadata{})
		busyAgent, _, _ := models.RegisterAgent(orgID, "s1-test-5", "test-5-001", models.AgentMetadata{})

		// assign some work to one of the agents
		models.ForcefullyOccupyAgentWithJobID(busyAgent)

		// disable only idle agents
		request := &pb.DisableAllAgentsRequest{
			OrganizationId: orgID.String(),
			AgentType:      "s1-test-4",
			OnlyIdle:       true,
		}

		_, err := service.DisableAllAgents(context.Background(), request)
		require.NoError(t, err)

		// assert agents of other agent type are not disabled
		agents, _, err := models.ListAgentsWithCursor(orgID, "s1-test-5", 100, "")
		require.NoError(t, err)
		if assert.Len(t, agents, 1) {
			assertDisabledAtIsNotSet(t, agents)
		}

		agents, _, err = models.ListAgentsWithCursor(orgID, "s1-test-4", 100, "")
		require.NoError(t, err)
		if assert.Len(t, agents, 2) {
			for _, agent := range agents {
				if agent.Name == busyAgent.Name {
					// assert busy agent is not disabled
					assert.Nil(t, agent.DisabledAt)
				} else {
					// assert idle agent is disabled
					assert.NotNil(t, agent.DisabledAt)
				}
			}
		}
	})
}

func assertDisabledAtIsSet(t *testing.T, now time.Time, agents []models.Agent) {
	for _, agent := range agents {
		require.NotNil(t, agent.DisabledAt)
		require.WithinDuration(t, now, *agent.DisabledAt, 100*time.Millisecond)
	}
}

func assertDisabledAtIsNotSet(t *testing.T, agents []models.Agent) {
	for _, agent := range agents {
		require.Nil(t, agent.DisabledAt)
	}
}
