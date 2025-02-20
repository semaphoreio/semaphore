package models

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	uuid "github.com/google/uuid"
	database "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/database"
	securetoken "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/securetoken"
	"gorm.io/gorm"

	pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/self_hosted"
)

var (
	NameAssignmentOriginFromAgent        = pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT.String()
	NameAssignmentOriginFromAWSSTS       = pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS.String()
	MinReleaseNameAfter            int64 = 60
)

type AgentType struct {
	OrganizationID uuid.UUID
	RequesterID    *uuid.UUID
	Name           string
	TokenHash      string

	AgentNameSettings

	CreatedAt *time.Time
	UpdatedAt *time.Time
}

type AgentNameSettings struct {
	NameAssignmentOrigin string
	ReleaseNameAfter     int64
	AWSAccount           string
	AWSRoleNamePatterns  string
}

func NewAgentNameSettings(reqSettings *pb.AgentNameSettings) (*AgentNameSettings, error) {
	if reqSettings == nil {
		return &AgentNameSettings{
			NameAssignmentOrigin: NameAssignmentOriginFromAgent,
			ReleaseNameAfter:     0,
			AWSAccount:           "",
			AWSRoleNamePatterns:  "",
		}, nil
	}

	if err := validateReleaseAfter(reqSettings.ReleaseAfter); err != nil {
		return nil, err
	}

	switch reqSettings.AssignmentOrigin {
	case pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT:
		if reqSettings.Aws != nil && reqSettings.Aws.AccountId != "" {
			return nil, fmt.Errorf("AWS account ID is not allowed for %s", reqSettings.AssignmentOrigin.String())
		}

		if reqSettings.Aws != nil && reqSettings.Aws.RoleNamePatterns != "" {
			return nil, fmt.Errorf("AWS role name patterns are not allowed for %s", reqSettings.AssignmentOrigin.String())
		}

		return &AgentNameSettings{
			NameAssignmentOrigin: reqSettings.AssignmentOrigin.String(),
			ReleaseNameAfter:     reqSettings.ReleaseAfter,
		}, nil
	case pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AWS_STS:
		if reqSettings.Aws == nil {
			return nil, fmt.Errorf("AWS information missing")
		}

		if reqSettings.Aws.AccountId == "" {
			return nil, fmt.Errorf("AWS account cannot be empty")
		}

		if reqSettings.Aws.RoleNamePatterns == "" {
			return nil, fmt.Errorf("AWS role name patterns cannot be empty")
		}

		return &AgentNameSettings{
			NameAssignmentOrigin: reqSettings.AssignmentOrigin.String(),
			ReleaseNameAfter:     reqSettings.ReleaseAfter,
			AWSAccount:           reqSettings.Aws.AccountId,
			AWSRoleNamePatterns:  reqSettings.Aws.RoleNamePatterns,
		}, nil
	default:
		return nil, fmt.Errorf("assignment origin not supported")
	}
}

func validateReleaseAfter(releaseAfter int64) error {
	if releaseAfter < 0 {
		return fmt.Errorf("name release hold must be 0 or greater than %d", MinReleaseNameAfter)
	}

	if releaseAfter > 0 && releaseAfter < MinReleaseNameAfter {
		return fmt.Errorf("name release hold must be greater than %d", MinReleaseNameAfter)
	}

	return nil
}

func (s *AgentNameSettings) GetNameAssignmentMode() string {
	if s.NameAssignmentOrigin == "" {
		return pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT.String()
	}

	return s.NameAssignmentOrigin
}

func FindAgentType(orgID uuid.UUID, name string) (*AgentType, error) {
	return FindAgentTypeWithContext(context.Background(), orgID, name)
}

func FindAgentTypeWithContext(ctx context.Context, orgID uuid.UUID, name string) (*AgentType, error) {
	at := &AgentType{}

	query := database.Conn().WithContext(ctx)
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("name = ?", name)

	err := query.First(at).Error
	if err != nil {
		return nil, err
	}

	return at, nil
}

func FindAgentTypeByToken(orgID string, tokenHash string) (*AgentType, error) {
	return FindAgentTypeByTokenWithContext(context.Background(), orgID, tokenHash)
}

func FindAgentTypeByTokenWithContext(ctx context.Context, orgID string, tokenHash string) (*AgentType, error) {
	at := &AgentType{}

	query := database.Conn().WithContext(ctx)
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("token_hash = ?", tokenHash)

	err := query.First(at).Error
	if err != nil {
		return nil, err
	}

	return at, nil
}

func CreateAgentType(orgID uuid.UUID, requesterID *uuid.UUID, name string) (*AgentType, string, error) {
	return CreateAgentTypeWithSettings(orgID, requesterID, name, AgentNameSettings{
		NameAssignmentOrigin: pb.AgentNameSettings_ASSIGNMENT_ORIGIN_AGENT.String(),
	})
}

func CreateAgentTypeWithSettings(orgID uuid.UUID, requesterID *uuid.UUID, name string, agentNameSettings AgentNameSettings) (*AgentType, string, error) {
	token, err := securetoken.Create()
	if err != nil {
		return nil, "", err
	}

	at := &AgentType{
		OrganizationID:    orgID,
		RequesterID:       requesterID,
		Name:              name,
		TokenHash:         token.Hash,
		AgentNameSettings: agentNameSettings,
	}

	err = database.Conn().Create(at).Error
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return nil, "", fmt.Errorf("agent type name must by unique in the organization")
		}

		return nil, "", err
	}

	return at, token.Token, nil
}

func ListAgentTypes(orgID uuid.UUID) ([]AgentType, error) {
	var ats []AgentType

	query := database.Conn().Where("organization_id = ?", orgID).Order("created_at asc")

	err := query.Find(&ats).Error
	if err != nil {
		return []AgentType{}, err
	}

	return ats, nil
}

func ListAgentTypesWithCursor(orgID uuid.UUID, count int32, cursor string) ([]AgentType, string, error) {
	var ats []AgentType

	query := database.Conn().Where("organization_id = ?", orgID).Order("created_at asc")

	if cursor != "" {
		c, err := strconv.ParseInt(cursor, 10, 64)
		if err != nil {
			return nil, "", err
		}

		query = query.Where("(extract(EPOCH from created_at) * 1000) >= ?", c)
	}
	query = query.Limit(int(count + 1))

	err := query.Find(&ats).Error
	if err != nil {
		return []AgentType{}, "", err
	}

	nextCursor := ""
	pageSize := int(count)
	if len(ats) == int(count+1) {
		last := ats[len(ats)-1]
		pageSize = len(ats) - 1
		nextCursor = fmt.Sprintf("%d", last.CreatedAt.UnixMilli())
	}

	return ats[:pageSize], nextCursor, nil
}

type AgentTypeWithAgentCount struct {
	AgentType       *AgentType
	TotalAgentCount int
}

func FindAgentTypeWithAgentCount(orgID uuid.UUID, name string) (*AgentTypeWithAgentCount, error) {
	at, err := FindAgentType(orgID, name)
	if err != nil {
		return nil, err
	}

	var agentCount int64

	query := database.Conn()
	query = query.Model(&Agent{})
	query = query.Where("organization_id = ?", orgID)
	query = query.Where("agent_type_name = ?", name)
	query = query.Where("state = ?", AgentStateRegistered)

	err = query.Count(&agentCount).Error
	if err != nil {
		return nil, err
	}

	return &AgentTypeWithAgentCount{
		AgentType:       at,
		TotalAgentCount: int(agentCount),
	}, nil
}

func ListAgentTypesWithAgentCount(orgID uuid.UUID) ([]AgentTypeWithAgentCount, error) {
	ats, err := ListAgentTypes(orgID)
	if err != nil {
		return []AgentTypeWithAgentCount{}, err
	}

	counts, err := CountAgentsGroupedByAgentType(orgID)
	if err != nil {
		return []AgentTypeWithAgentCount{}, err
	}

	result := make([]AgentTypeWithAgentCount, len(ats))
	for i := range ats {
		result[i].AgentType = &ats[i]

		count, ok := counts[ats[i].Name]
		if !ok {
			count = 0
		}

		result[i].TotalAgentCount = count
	}

	return result, nil
}

func ListCursorAgentTypesWithAgentCount(orgID uuid.UUID, count int32, cursor string) ([]AgentTypeWithAgentCount, string, error) {
	ats, nextCursor, err := ListAgentTypesWithCursor(orgID, count, cursor)
	if err != nil {
		return []AgentTypeWithAgentCount{}, "", err
	}

	counts, err := CountAgentsGroupedByAgentType(orgID)
	if err != nil {
		return []AgentTypeWithAgentCount{}, "", err
	}

	result := make([]AgentTypeWithAgentCount, len(ats))
	for i := range ats {
		result[i].AgentType = &ats[i]
		result[i].TotalAgentCount = counts[ats[i].Name]
	}

	return result, nextCursor, nil
}

func DisableAllAgents(orgID uuid.UUID, agentTypeName string) error {
	now := time.Now()
	return database.Conn().
		Model(&Agent{}).
		Where("organization_id = ? AND agent_type_name = ?", orgID, agentTypeName).
		Updates(Agent{DisabledAt: &now}).
		Error
}

func DisableOnlyIdleAgents(orgID uuid.UUID, agentTypeName string) error {
	now := time.Now()
	return database.Conn().
		Model(&Agent{}).
		Where("organization_id = ? AND agent_type_name = ? AND assigned_job_id IS NULL", orgID, agentTypeName).
		Updates(Agent{DisabledAt: &now}).
		Error
}

var ErrCantDeleteAgentTypeWithExistingAgents = errors.New("can't delete agent type with existing agents")

const AgentTypeReferenceKeySQLError = `update or delete on table "agent_types" violates foreign key constraint "agents_organization_id_fkey" on table "agents`

func (a *AgentType) Delete() error {
	return database.Conn().Transaction(func(tx *gorm.DB) error {

		//
		// Delete disconnected agents first.
		//
		err := tx.Where("agent_type_name = ?", a.Name).
			Where("organization_id = ?", a.OrganizationID).
			Where("state", AgentStateDisconnected).
			Delete(&Agent{}).Error

		if err != nil {
			return err
		}

		//
		// Now, try to delete the agent type.
		// The deletion will only fail now if there are registered agents available.
		//
		err = tx.Where("name = ? and organization_id = ?", a.Name, a.OrganizationID).Delete(&AgentType{}).Error
		if err != nil {
			if strings.Contains(err.Error(), AgentTypeReferenceKeySQLError) {
				return ErrCantDeleteAgentTypeWithExistingAgents
			}

			return err
		}

		return nil
	})
}

func (a *AgentType) Update() error {
	return database.Conn().Where("name = ? and organization_id = ?", a.Name, a.OrganizationID).Save(a).Error
}

func (a *AgentType) ResetToken(requesterID *uuid.UUID) (string, error) {
	token, err := securetoken.Create()
	if err != nil {
		return "", err
	}

	fieldsToUpdate := AgentType{
		TokenHash:   token.Hash,
		RequesterID: requesterID,
	}

	query := database.Conn().Model(&a)
	query = query.Where("organization_id = ?", a.OrganizationID)
	query = query.Where("name = ?", a.Name)

	err = query.Updates(fieldsToUpdate).Error
	if err != nil {
		return "", err
	}

	return token.Token, nil
}
