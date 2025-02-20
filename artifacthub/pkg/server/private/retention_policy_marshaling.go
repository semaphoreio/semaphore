package privateserver

import (
	"errors"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"go.uber.org/zap"
	"google.golang.org/grpc/codes"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func marshalRetentionPolicyRuleToModel(rules []*artifacthub.RetentionPolicy_RetentionPolicyRule) models.RetentionPolicyRules {
	r := models.RetentionPolicyRules{}

	for _, rule := range rules {
		r.Rules = append(r.Rules, models.RetentionPolicyRuleItem{
			Selector: rule.Selector,
			Age:      int(rule.Age),
		})
	}

	return r
}

func marshalRetentionPolicyModelToAPIModel(m *models.RetentionPolicy) (*artifacthub.RetentionPolicy, error) {
	marshaled := &artifacthub.RetentionPolicy{
		ProjectLevelRetentionPolicies:  marshalRetentionPolicyRulesModelToAPIModel(&m.ProjectLevelPolicies),
		WorkflowLevelRetentionPolicies: marshalRetentionPolicyRulesModelToAPIModel(&m.WorkflowLevelPolicies),
		JobLevelRetentionPolicies:      marshalRetentionPolicyRulesModelToAPIModel(&m.JobLevelPolicies),
	}

	if m.LastCleanedAt != nil {
		marshaled.LastCleanedAt = timestamppb.New(*m.LastCleanedAt)
	}

	if m.ScheduledForCleaningAt != nil {
		marshaled.ScheduledForCleaningAt = timestamppb.New(*m.ScheduledForCleaningAt)
	}

	return marshaled, nil
}

func marshalRetentionPolicyRulesModelToAPIModel(m *models.RetentionPolicyRules) []*artifacthub.RetentionPolicy_RetentionPolicyRule {
	r := []*artifacthub.RetentionPolicy_RetentionPolicyRule{}

	for _, rule := range m.Rules {
		r = append(r, &artifacthub.RetentionPolicy_RetentionPolicyRule{
			Selector: rule.Selector,
			Age:      int64(rule.Age),
		})
	}

	return r
}

func marshalRetentionPolicyUpdateError(err error) error {
	if errors.Is(err, models.ErrRetentionPolicyAgeTooShort) {
		return log.ErrorCode(codes.FailedPrecondition, err.Error(), nil)
	}

	if errors.Is(err, models.ErrRetentionPolicyTooLong) {
		return log.ErrorCode(codes.FailedPrecondition, err.Error(), nil)
	}

	if errors.Is(err, models.ErrRetentionPolicySelectorTooLong) {
		return log.ErrorCode(codes.FailedPrecondition, err.Error(), nil)
	}

	log.Error("(err) unhandled error while updating retention policy", zap.Error(err))

	return log.ErrorCode(codes.Internal, "internal error while updating retention policy", nil)
}
