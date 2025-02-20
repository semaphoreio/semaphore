package agentcounter

import (
	"fmt"
	"sync"
	"time"

	uuid "github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
)

type AgentCounter struct {
	Lock                 sync.Mutex
	Interval             *time.Duration
	AgentsInOrganization []AgentsInOrganization
}

type AgentCounterConfig struct {
	Interval *time.Duration
}

func NewAgentCounter(interval *time.Duration) (*AgentCounter, error) {
	if interval == nil {
		return nil, fmt.Errorf("interval cannot be nil")
	}

	return &AgentCounter{
		Interval:             interval,
		AgentsInOrganization: []AgentsInOrganization{},
	}, nil
}

func (c *AgentCounter) Start() {
	for {
		c.tick()
		time.Sleep(*c.Interval)
	}
}

func (c *AgentCounter) Refresh() {
	c.tick()
}

func (c *AgentCounter) Get(orgID string) int {
	for _, item := range c.AgentsInOrganization {
		if item.OrganizationID.String() == orgID {
			return item.Count
		}
	}

	return 0
}

func (c *AgentCounter) tick() {
	c.Lock.Lock()
	defer c.Lock.Unlock()

	log.Info("Counting number of agents in organizations")
	agentsInOrganization, err := c.countAgentsInOrganization()
	if err != nil {
		log.Errorf("Error counting number of agents in organizations: %v", err)
		return
	}

	c.AgentsInOrganization = agentsInOrganization
	for _, count := range agentsInOrganization {
		c.publishMetric("agents.count", count.OrganizationID.String(), int(count.Count))
	}
}

type AgentsInOrganization struct {
	OrganizationID uuid.UUID
	Count          int
}

func (c *AgentCounter) countAgentsInOrganization() ([]AgentsInOrganization, error) {
	counts := []AgentsInOrganization{}

	query := database.Conn()
	query = query.Model(&models.Agent{})
	query = query.Where("disabled_at IS NULL")
	query = query.Where("state = ?", models.AgentStateRegistered)
	query = query.Group("organization_id")
	query = query.Order("Count DESC")
	query = query.Select("organization_id, COUNT(*) as Count")

	err := query.Scan(&counts).Error
	if err != nil {
		return nil, err
	}

	return counts, nil
}

func (c *AgentCounter) publishMetric(metricName, tag string, value int) {
	err := watchman.SubmitWithTags(metricName, []string{tag}, value)
	if err != nil {
		log.Errorf("Error publishing %s for %s: %v", metricName, tag, err)
	}
}
