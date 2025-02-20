package models

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"

	uuid "github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var ErrAgentCantBeRegistered = errors.New("agent can't be registered")
var AgentStateRegistered = "registered"
var AgentStateDisconnected = "disconnected"
var agentNameRegex = regexp.MustCompile("^[a-zA-Z0-9-_/+]+$")
var agentNameMaxCharacters = 80

type AgentMetadata struct {
	Version                 string
	OS                      string
	Arch                    string
	PID                     int `gorm:"column:pid"`
	Hostname                string
	UserAgent               string
	IPAddress               string
	SingleJob               bool
	IdleTimeout             int
	InterruptionGracePeriod int
}

type Agent struct {
	ID uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`

	OrganizationID uuid.UUID
	AgentTypeName  string
	Name           string
	TokenHash      string
	State          string

	CreatedAt      *time.Time
	UpdatedAt      *time.Time
	DisabledAt     *time.Time
	InterruptedAt  *time.Time
	DisconnectedAt *time.Time

	LastSyncAt    *time.Time
	LastSyncState string
	LastSyncJobID string

	AssignedJobID      *uuid.UUID
	JobAssignedAt      *time.Time
	JobStopRequestedAt *time.Time
	LastStateChangeAt  *time.Time

	AgentMetadata
}

func ValidateAgentName(name string) (string, error) {
	if len(name) > agentNameMaxCharacters {
		return "", fmt.Errorf("the agent name '%s' is invalid: must be below %d characters", name, agentNameMaxCharacters)
	}

	if !agentNameRegex.MatchString(name) {
		return "", fmt.Errorf("the agent name '%s' is invalid: must follow the pattern %s", name, agentNameRegex.String())
	}

	return name, nil
}

func RegisterAgent(orgID uuid.UUID, agentTypeName string, name string, metadata AgentMetadata) (*Agent, string, error) {
	return RegisterAgentInTransaction(database.Conn(), orgID, agentTypeName, name, nil, metadata)
}

func RegisterAgentInTransaction(tx *gorm.DB, orgID uuid.UUID, agentTypeName, name string, job *uuid.UUID, metadata AgentMetadata) (*Agent, string, error) {
	token, err := securetoken.Create()
	if err != nil {
		return nil, "", err
	}

	a := Agent{
		State:          AgentStateRegistered,
		OrganizationID: orgID,
		AgentTypeName:  agentTypeName,
		Name:           name,
		TokenHash:      token.Hash,
		AgentMetadata:  metadata,
	}

	// We do this in a nested transaction,
	// because if the insert fails, we still need to registerAgentRetry().
	// If we don't do this, we get a `current transaction is aborted, commands ignored until end of transaction block` error.
	err = tx.Transaction(func(tx2 *gorm.DB) error {
		return tx2.Create(&a).Error
	})

	if err != nil {
		if isAgentNameNotUnique(err) {
			return registerAgentRetry(tx, orgID, agentTypeName, name)
		}

		return nil, "", err
	}

	// If job is passed, we also occupy the agent in the same transaction
	if job != nil {
		err = tx.Transaction(func(tx2 *gorm.DB) error {
			_, err := OccupyAgentInTransaction(tx2, &a, job)
			return err
		})

		if err != nil {
			return nil, "", err
		}
	}

	return &a, token.Token, nil
}

// This method is used to implement agent registration idempotency.
//
// Agent idempotency is based on the name of the agent, a value that is randomly
// generated in the Agent, and sent as part of the Registration request.
//
// True agent registration idempotency is not possible because we don't store
// the value of the Access Token that is given out after registration in our
// database. We only store the hashed value of that token.
//
// As true idempotency is not possible, we fall back to a semi-idempotent action.
//
// ---
//
// Why we need an idempotent action?
//
// Consider the following case:
//
// 1. The Agent sends a POST /register action
// 2. The Hub saves the agent in the DB, and generates a token
// 3. The Hub's answer never reaches the Agent
//
// At this point, the agent needs to retry.
// 1. If it retries with a different name: We will register two agents in the DB. Not good.
// 2. If it retries with the same name: It will get a name not unique error. Not good.
//
// ---
//
// # Implementation of the semi-idempotent action
//
// In case the RegisterAgent gets a "not unique name" while writing to the
// database, we run this function. This function then:
//
// 1. Finds the Agent with the same name
// 2. Generates a new token
// 3. Updates the existing agent in the DB
//
// ---
//
// Limits:
//
// This idempotent action is available only 5 minutes since the original agent is
// created in the database. After that, the upstream will return an error.
func registerAgentRetry(tx *gorm.DB, orgID uuid.UUID, agentTypeName string, name string) (*Agent, string, error) {
	query := tx.Where("organization_id = ?", orgID)
	query = query.Where("agent_type_name = ?", agentTypeName)
	query = query.Where("name = ?", name)
	query = query.Where("last_sync_at IS NULL")

	agent := &Agent{}
	err := query.First(agent).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", ErrAgentCantBeRegistered
		}

		return nil, "", err
	}

	if !agent.CanAcceptRegistrationRetries() {
		// this agent was registered more than 5 minutes ago
		// we do not accept idempotent requests anymore

		return nil, "", ErrAgentCantBeRegistered
	}

	token, err := securetoken.Create()
	if err != nil {
		return nil, "", err
	}

	agent.TokenHash = token.Hash
	err = tx.Model(&agent).Update("token_hash", token.Hash).Error
	if err != nil {
		return nil, "", err
	}

	return agent, token.Token, nil
}

func (a *Agent) CanAcceptRegistrationRetries() bool {
	return a.CreatedAt.After(time.Now().Add(-5 * time.Minute))
}

func isAgentNameNotUnique(err error) bool {
	return strings.Contains(
		err.Error(),
		`duplicate key value violates unique constraint "uix_agent_name_in_orgs"`,
	)
}

func FindAgentByToken(orgID string, tokenHash string) (*Agent, error) {
	return FindAgentByTokenWithContext(context.Background(), orgID, tokenHash)
}

func FindAgentByTokenWithContext(ctx context.Context, orgID string, tokenHash string) (*Agent, error) {
	at := &Agent{}

	query := database.Conn().WithContext(ctx)
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("token_hash = ?", tokenHash)

	err := query.First(at).Error
	if err != nil {
		return nil, err
	}

	return at, nil
}

func FindAgentByName(orgID string, name string) (*Agent, error) {
	at := &Agent{}

	query := database.Conn()
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("name = ?", name)

	err := query.First(at).Error
	if err != nil {
		return nil, err
	}

	return at, nil
}

func ListAgentsWithCursor(orgID uuid.UUID, agentTypeName string, count int32, cursor string) ([]Agent, string, error) {
	agents := []Agent{}

	query := database.Conn()
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("state = ?", AgentStateRegistered)

	if agentTypeName != "" {
		query = query.Where("agent_type_name = ?", agentTypeName)
	}

	if cursor != "" {
		c, err := strconv.ParseInt(cursor, 10, 64)
		if err != nil {
			return nil, "", err
		}

		query = query.Where("(extract(EPOCH from created_at) * 1000) >= ?", c)
	}

	query = query.Order("created_at ASC")
	query = query.Limit(int(count + 1))
	err := query.Find(&agents).Error
	if err != nil {
		return nil, "", err
	}

	// If no records are returned,
	// or the number of records returned is below the
	// number of records requested, no cursor is returned.
	if len(agents) == 0 || len(agents) <= int(count) {
		return agents, "", nil
	}

	// Otherwise, we use the last element as the cursor.
	last := agents[len(agents)-1]
	nextCursor := fmt.Sprintf("%d", last.CreatedAt.UnixMilli())
	return agents[0 : len(agents)-1], nextCursor, nil
}

type AgentsInState struct {
	Busy int
	Idle int
}

func CountAllAgentsInState() (*AgentsInState, error) {
	counts := AgentsInState{}

	err := database.Conn().
		Raw(`
			select
				COUNT(*) FILTER (WHERE assigned_job_id IS NULL) idle,
				COUNT(*) FILTER (WHERE assigned_job_id IS NOT NULL) busy
			FROM (
				select assigned_job_id from agents
			) as ids;
		`).
		Scan(&counts).
		Error

	if err != nil {
		return nil, err
	}

	return &counts, nil
}

func CountAgentsInStateForType(ctx context.Context, orgID, agentTypeName string) (*AgentsInState, error) {
	counts := AgentsInState{}

	err := database.Conn().WithContext(ctx).
		Raw(`
			select
				COUNT(*) FILTER (WHERE assigned_job_id IS NULL) idle,
				COUNT(*) FILTER (WHERE assigned_job_id IS NOT NULL) busy
			FROM (
				select assigned_job_id from agents where organization_id = ? and agent_type_name = ?
			) as ids;
		`, orgID, agentTypeName).
		Scan(&counts).
		Error

	if err != nil {
		return nil, err
	}

	return &counts, nil
}

func CountAgentsInOrganization(orgID string) (int, error) {
	return CountAgentsInOrganizationInTransaction(context.Background(), database.Conn(), orgID)
}

func CountAgentsInOrganizationInTransaction(ctx context.Context, tx *gorm.DB, orgID string) (int, error) {
	var agentCount int64

	query := tx.Model(&Agent{}).WithContext(ctx)
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("state = ?", AgentStateRegistered)

	err := query.Count(&agentCount).Error
	if err != nil {
		return 0, err
	}

	return int(agentCount), nil
}

func CountNotDisabledAgentsInOrganization(orgID string) (int, error) {
	var agentCount int64

	query := database.Conn()
	query = query.Model(&Agent{})
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("disabled_at IS NULL")

	err := query.Count(&agentCount).Error
	if err != nil {
		return 0, err
	}

	return int(agentCount), nil
}

func CountAgentsGroupedByAgentType(orgID uuid.UUID) (map[string]int, error) {
	counts := [](struct {
		OrganizationID uuid.UUID
		AgentTypeName  string
		Count          int64
	}){}

	query := database.Conn()
	query = query.Model(&Agent{})
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("state = ?", AgentStateRegistered)
	query = query.Group("organization_id, agent_type_name")
	query = query.Select("organization_id, agent_type_name, COUNT(*) as Count")

	err := query.Scan(&counts).Error
	if err != nil {
		return nil, err
	}

	result := make(map[string]int)

	for i := range counts {
		result[counts[i].AgentTypeName] = int(counts[i].Count)
	}

	return result, nil
}

func SyncAgent(orgID, tokenHash, state, jobID string, interruptedAt int64) (*Agent, error) {
	return SyncAgentWithContext(context.Background(), orgID, tokenHash, state, jobID, interruptedAt)
}

func SyncAgentWithContext(ctx context.Context, orgID, tokenHash, state, jobID string, interruptedAt int64) (*Agent, error) {
	t := time.Now()

	updates := map[string]interface{}{
		"last_sync_at":    &t,
		"last_sync_state": state,
		"last_state_change_at": gorm.Expr(
			"case when last_sync_state != ? then ? else last_state_change_at end", state, &t,
		),
	}

	if jobID != "" {
		updates["last_sync_job_id"] = jobID
	}

	if interruptedAt > 0 {
		t := time.Unix(interruptedAt, 0)
		updates["interrupted_at"] = &t
	}

	var agent Agent
	result := database.Conn().WithContext(ctx).
		Clauses(clause.Returning{}).
		Model(&agent).
		Where("organization_id = ?", orgID).
		Where("token_hash = ?", tokenHash).
		Updates(updates)

	if result.Error != nil {
		return nil, result.Error
	}

	if result.RowsAffected == 0 {
		return nil, gorm.ErrRecordNotFound
	}

	return &agent, nil
}

func FindAlreadyOccupied(orgID uuid.UUID, agentTypeName string, jobID uuid.UUID) (*Agent, error) {
	agent := &Agent{}

	query := database.Conn()
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("agent_type_name = ?", agentTypeName)
	query = query.Where("assigned_job_id = ?", jobID)

	err := query.First(agent).Error
	return agent, err
}

func OccupyAgent(agent *Agent) (string, error) {
	return OccupyAgentInTransaction(database.Conn(), agent, nil)
}

func OccupyAgentInTransaction(tx *gorm.DB, agent *Agent, requestJobID *uuid.UUID) (string, error) {
	var jobID uuid.UUID

	err := tx.Transaction(func(db *gorm.DB) error {
		// find an occupation request
		query := db.Clauses(clause.Locking{Strength: "UPDATE SKIP LOCKED"})
		query = query.Where("organization_id = ?", agent.OrganizationID)
		query = query.Where("agent_type_name = ?", agent.AgentTypeName)

		if requestJobID != nil {
			query = query.Where("job_id = ?", requestJobID)
		} else {
			query = query.Order("created_at ASC")
		}

		request := &OccupationRequest{}
		err := query.First(&request).Error
		if err != nil {
			return err
		}

		// update agent's assigned job ID
		now := time.Now()
		jobID = request.JobID
		fieldsToUpdate := Agent{
			AssignedJobID:      &jobID,
			JobAssignedAt:      &now,
			JobStopRequestedAt: nil,
		}

		err = db.Model(agent).Updates(fieldsToUpdate).Error
		if err != nil {
			return err
		}

		// delete occupation request
		return db.Delete(request).Error
	})

	if err != nil {
		return "", err
	}

	return jobID.String(), nil
}

// WARNING: this should only be used during tests.
func ForcefullyOccupyAgentWithJobID(agent *Agent) (uuid.UUID, error) {
	jobID := database.UUID()
	now := time.Now()

	updates := Agent{
		AssignedJobID: &jobID,
		JobAssignedAt: &now,
	}

	return jobID, database.Conn().Model(agent).Updates(updates).Error
}

func ReleaseAgent(orgID uuid.UUID, agentTypeName string, jobID uuid.UUID) (*Agent, error) {
	agent := &Agent{}

	err := database.Conn().Transaction(func(db *gorm.DB) error {
		query := db.Where("organization_id = ?", orgID)
		query = query.Where("assigned_job_id = ?", jobID)

		err := query.First(&agent).Error
		if err != nil {
			return err
		}

		agent.JobAssignedAt = nil
		agent.AssignedJobID = nil
		agent.JobStopRequestedAt = nil

		return db.Save(agent).Error
	})

	if err != nil {
		return nil, err
	}

	return agent, nil
}

func DisableAgent(orgID uuid.UUID, agentTypeName, agentName string) (*Agent, error) {
	agent := &Agent{}

	err := database.Conn().Transaction(func(db *gorm.DB) error {
		query := db.Where("organization_id = ?", orgID)
		query = query.Where("agent_type_name = ?", agentTypeName)
		query = query.Where("name = ?", agentName)

		err := query.First(&agent).Error
		if err != nil {
			return err
		}

		now := time.Now()
		agent.DisabledAt = &now
		return db.Save(agent).Error
	})

	if err != nil {
		return nil, err
	}

	return agent, nil
}

func StopJob(orgID uuid.UUID, jobID uuid.UUID) error {
	err := database.Conn().Transaction(func(db *gorm.DB) error {
		request := OccupationRequest{}
		err := db.
			Where("organization_id = ?", orgID).
			Where("job_id = ?", jobID).
			First(&request).
			Error

		// Occupation request exists, so job wasn't assigned to any agents yet.
		// Just delete the occupation request.
		if err == nil {
			return db.Delete(&request).Error
		}

		// Request does not exist, so job was already assigned to agent.
		// The agent needs to be stopped.
		agent := Agent{}
		err = db.
			Where("organization_id = ?", orgID).
			Where("assigned_job_id = ?", jobID).
			First(&agent).
			Error
		if err != nil {
			return err
		}

		now := time.Now()
		agent.JobStopRequestedAt = &now

		return db.Save(agent).Error
	})

	if err != nil {
		return err
	}

	return nil
}

func (a *Agent) IsRunningJob(jobID string) bool {
	return a.AssignedJobID != nil && a.AssignedJobID.String() == jobID
}

func (a *Agent) Disconnect() error {
	return a.DisconnectWithContext(context.Background())
}

func (a *Agent) DisconnectWithContext(ctx context.Context) error {
	agentType, err := FindAgentTypeWithContext(ctx, a.OrganizationID, a.AgentTypeName)
	if err != nil {
		return err
	}

	if agentType.ReleaseNameAfter == 0 {
		return database.Conn().Delete(a).Error
	}

	now := time.Now()
	return database.Conn().WithContext(ctx).
		Model(&a).
		Updates(map[string]interface{}{
			"state":           AgentStateDisconnected,
			"disconnected_at": now,
		}).Error
}
