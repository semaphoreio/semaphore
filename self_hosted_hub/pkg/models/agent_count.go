package models

import (
	"context"
	"errors"

	uuid "github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	gorm "gorm.io/gorm"
)

// AgentCount holds the number of registered agents in an organization.
// A database trigger on the agents table keeps it up to date:
// every insert, delete or state change of an agent updates the organization's row,
// in the same transaction as the agent change.
//
// Since the trigger updates the row, a transaction that registers an agent
// holds the row lock until it commits. Concurrent registrations for the same
// organization queue on that row, and reading the count after inserting
// the agent gives an exact number to compare against the quota.
type AgentCount struct {
	OrganizationID uuid.UUID `gorm:"primary_key"`
	Registered     int
}

func (AgentCount) TableName() string {
	return "agent_counts"
}

// RegisteredAgentCountInTransaction returns the number of registered agents for the organization,
// as seen by the transaction. Organizations without a row have no registered agents.
func RegisteredAgentCountInTransaction(ctx context.Context, tx *gorm.DB, orgID uuid.UUID) (int, error) {
	count := AgentCount{}
	err := tx.WithContext(ctx).Where("organization_id = ?", orgID).Take(&count).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return 0, nil
		}

		return 0, err
	}

	return count.Registered, nil
}

func RegisteredAgentCount(orgID uuid.UUID) (int, error) {
	return RegisteredAgentCountInTransaction(context.Background(), database.Conn(), orgID)
}
