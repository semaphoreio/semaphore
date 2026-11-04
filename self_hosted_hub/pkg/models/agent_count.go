package models

import (
	"context"
	"errors"

	uuid "github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	log "github.com/sirupsen/logrus"
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

type AgentCountDrift struct {
	OrganizationID uuid.UUID
	Counted        int
	Stored         int
}

// ReconcileAgentCounts fixes organization counts that don't match the agents table.
// The trigger keeps them in sync, so this only finds something if agents were changed
// with the trigger disabled, or the table was truncated.
//
// Finding candidates is a single aggregate without locks. Each candidate is then
// recounted while holding its counter row lock, which makes the fix exact:
// concurrent agent changes either committed before the lock was taken, and are counted,
// or wait for the lock, and apply their change on top of the fixed value.
func ReconcileAgentCounts(ctx context.Context) ([]AgentCountDrift, error) {
	candidates := []AgentCountDrift{}
	err := database.Conn().WithContext(ctx).Raw(`
		SELECT
			COALESCE(a.organization_id, c.organization_id) AS organization_id,
			COALESCE(a.counted, 0) AS counted,
			COALESCE(c.registered, 0) AS stored
		FROM (
			SELECT organization_id, COUNT(*) AS counted
			FROM agents
			WHERE state = ?
			GROUP BY organization_id
		) a
		FULL OUTER JOIN agent_counts c ON c.organization_id = a.organization_id
		WHERE COALESCE(a.counted, 0) <> COALESCE(c.registered, 0)
	`, AgentStateRegistered).Scan(&candidates).Error

	if err != nil {
		return nil, err
	}

	fixed := []AgentCountDrift{}
	for _, candidate := range candidates {
		drift, err := reconcileAgentCount(ctx, candidate.OrganizationID)
		if err != nil {
			log.Errorf("Error reconciling agent count for organization %s: %v", candidate.OrganizationID, err)
			continue
		}

		if drift != nil {
			fixed = append(fixed, *drift)
		}
	}

	return fixed, nil
}

func reconcileAgentCount(ctx context.Context, orgID uuid.UUID) (*AgentCountDrift, error) {
	var drift *AgentCountDrift

	err := database.Conn().WithContext(ctx).Transaction(func(tx *gorm.DB) error {
		err := tx.Exec(`
			INSERT INTO agent_counts (organization_id, registered) VALUES (?, 0)
			ON CONFLICT (organization_id) DO NOTHING
		`, orgID).Error
		if err != nil {
			return err
		}

		var stored int
		err = tx.Raw(`SELECT registered FROM agent_counts WHERE organization_id = ? FOR UPDATE`, orgID).Row().Scan(&stored)
		if err != nil {
			return err
		}

		var counted int64
		err = tx.Model(&Agent{}).
			Where("organization_id = ?", orgID).
			Where("state = ?", AgentStateRegistered).
			Count(&counted).Error
		if err != nil {
			return err
		}

		if int(counted) == stored {
			return nil
		}

		drift = &AgentCountDrift{OrganizationID: orgID, Counted: int(counted), Stored: stored}
		return tx.Exec(`UPDATE agent_counts SET registered = ? WHERE organization_id = ?`, counted, orgID).Error
	})

	return drift, err
}
