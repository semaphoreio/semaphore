package metrics

import (
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/models"
	log "github.com/sirupsen/logrus"
)

type Collector struct {
}

func NewCollector() *Collector {
	return &Collector{}
}

func (c *Collector) Start() {
	for {
		c.tick()
		time.Sleep(1 * time.Minute)
	}
}

func (c *Collector) tick() {
	log.Info("Collecting metric for agents in state")
	agentsInState, err := c.CountAgentsInState()
	if err != nil {
		log.Errorf("Error collecting metric for agents in state: %v", err)
	}

	c.publishMetric("agents.state.count", "busy", int(agentsInState.Busy))
	c.publishMetric("agents.state.count", "idle", int(agentsInState.Idle))

	c.publishExternalMetric("Agents.state", []string{"state", "busy"}, int(agentsInState.Busy))
	c.publishExternalMetric("Agents.state", []string{"state", "idle"}, int(agentsInState.Idle))

	log.Info("Collecting metric for agents in version")
	agentsInVersion, err := c.CountAgentsInVersion()
	if err != nil {
		log.Errorf("Error collecting metric for agents in version: %v", err)
	}

	for _, count := range agentsInVersion {
		c.publishMetric("agents.version.count", count.Version, int(count.Count))
		c.publishExternalMetric("Agents.version", []string{"version", count.Version}, int(count.Count))
	}
}

func (c *Collector) publishMetric(metricName, tag string, value int) {
	err := watchman.SubmitWithTags(metricName, []string{tag}, value)
	if err != nil {
		log.Errorf("Error publishing %s for %s: %v", metricName, tag, err)
	}
}

func (c *Collector) publishExternalMetric(metricName string, tag []string, value int) {
	err := watchman.External().SubmitWithTags(metricName, tag, value)
	if err != nil {
		log.Errorf("Error publishing %s for %s: %v", metricName, tag, err)
	}
}

func (c *Collector) CountAgentsInState() (*models.AgentsInState, error) {
	return models.CountAllAgentsInState()
}

type AgentsInVersion struct {
	Version string
	Count   int64
}

func (c *Collector) CountAgentsInVersion() ([]AgentsInVersion, error) {
	counts := []AgentsInVersion{}

	query := database.Conn()
	query = query.Model(&models.Agent{})
	query = query.Group("version")
	query = query.Order("Count DESC")
	query = query.Select("version, COUNT(*) as Count")

	err := query.Scan(&counts).Error
	if err != nil {
		return nil, err
	}

	return counts, nil
}
