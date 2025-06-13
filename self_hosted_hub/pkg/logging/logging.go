package logging

import (
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
)

func ForAgent(agent *models.Agent) *log.Entry {
	if agent == nil {
		return log.WithFields(log.Fields{})
	}

	return log.WithFields(
		log.Fields{
			"agent_id":        agent.ID,
		},
	)
}

func ForAgentType(agentType *models.AgentType) *log.Entry {
	if agentType == nil {
		return log.WithFields(log.Fields{})
	}

	return log.WithFields(
		log.Fields{
			"organization_id": agentType.OrganizationID,
			"agent_type":      agentType.Name,
		},
	)
}
