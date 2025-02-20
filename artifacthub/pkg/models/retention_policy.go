package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	doublestar "github.com/bmatcuk/doublestar/v4"
	uuid "github.com/satori/go.uuid"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"gorm.io/gorm"
)

const MaxRetentionPolicyRules = 10
const MaxRetentionPolicySelectorLenght = 100
const MinRetentionPolicyAge = 24 * 3600 // one day

var ErrRetentionPolicyTooLong = fmt.Errorf("retention policy must have less than %d rules", MaxRetentionPolicyRules)
var ErrRetentionPolicySelectorTooLong = fmt.Errorf("retention policy selector length must be less than %d long", MaxRetentionPolicySelectorLenght)
var ErrRetentionPolicyAgeTooShort = fmt.Errorf("retention policy age can't be shorter than a day")

type RetentionPolicy struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	ArtifactID uuid.UUID

	ProjectLevelPolicies  RetentionPolicyRules
	WorkflowLevelPolicies RetentionPolicyRules
	JobLevelPolicies      RetentionPolicyRules

	ScheduledForCleaningAt *time.Time
	LastCleanedAt          *time.Time
}

func CreateRetentionPolicy(artifactID uuid.UUID, project, workflow, job RetentionPolicyRules) (*RetentionPolicy, error) {
	return CreateRetentionPolicyWithTx(db.Conn(), artifactID, project, workflow, job)
}

func CreateRetentionPolicyWithTx(tx *gorm.DB, artifactID uuid.UUID, project, workflow, job RetentionPolicyRules) (*RetentionPolicy, error) {
	r := &RetentionPolicy{
		ArtifactID:            artifactID,
		ProjectLevelPolicies:  project,
		WorkflowLevelPolicies: workflow,
		JobLevelPolicies:      job,
	}

	if err := r.Validate(); err != nil {
		return nil, err
	}

	err := tx.Create(r).Error
	if err != nil {
		return nil, err
	}

	return r, nil
}

func FindRetentionPolicy(artifactID uuid.UUID) (*RetentionPolicy, error) {
	return FindRetentionPolicyWithTx(db.Conn(), artifactID)
}

func FindRetentionPolicyWithTx(tx *gorm.DB, artifactID uuid.UUID) (*RetentionPolicy, error) {
	r := &RetentionPolicy{}

	err := tx.Where("artifact_id = ?", artifactID.String()).First(r).Error
	if err != nil {
		return nil, err
	}

	return r, nil
}

func FindRetentionPolicyOrReturnEmpty(artifactID uuid.UUID) (*RetentionPolicy, error) {
	policy, err := FindRetentionPolicy(artifactID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return &RetentionPolicy{}, nil
		}

		return nil, err
	}

	return policy, err
}

func UpdateRetentionPolicy(artifactID uuid.UUID, project, workflow, job RetentionPolicyRules) (*RetentionPolicy, error) {
	return UpdateRetentionPolicyWithTx(db.Conn(), artifactID, project, workflow, job)
}

func UpdateRetentionPolicyWithTx(tx *gorm.DB, artifactID uuid.UUID, project, workflow, job RetentionPolicyRules) (*RetentionPolicy, error) {
	r, err := FindRetentionPolicyWithTx(tx, artifactID)
	if err != nil {
		return CreateRetentionPolicyWithTx(tx, artifactID, project, workflow, job)
	}

	r.ProjectLevelPolicies = project
	r.WorkflowLevelPolicies = workflow
	r.JobLevelPolicies = job

	if err := r.Validate(); err != nil {
		return nil, err
	}

	err = tx.Save(r).Error
	if err != nil {
		return nil, err
	}

	return r, nil
}

func (r *RetentionPolicy) Validate() error {
	err := r.ProjectLevelPolicies.Validate()
	if err != nil {
		return err
	}

	err = r.WorkflowLevelPolicies.Validate()
	if err != nil {
		return err
	}

	err = r.JobLevelPolicies.Validate()
	if err != nil {
		return err
	}

	return nil
}

func (r *RetentionPolicy) IsMatching(path string, age time.Duration) bool {
	for _, p := range r.ProjectLevelPolicies.Rules {
		if p.isMatching("artifacts/projects/**", path) {
			return age > time.Duration(p.Age)*time.Second
		}
	}

	for _, p := range r.WorkflowLevelPolicies.Rules {
		if p.isMatching("artifacts/workflows/**", path) {
			return age > time.Duration(p.Age)*time.Second
		}
	}

	for _, p := range r.JobLevelPolicies.Rules {
		if p.isMatching("artifacts/jobs/**", path) {
			return age > time.Duration(p.Age)*time.Second
		}
	}

	return false
}

func (r *RetentionPolicy) Reload() error {
	return db.Conn().Where("artifact_id = ?", r.ArtifactID.String()).First(r).Error
}

func (r *RetentionPolicy) IsCleanedInLast24Hours() bool {
	if r.LastCleanedAt == nil {
		return false
	}

	return r.LastCleanedAt.After(time.Now().Add(-24 * time.Hour))
}

// Retention policy rules are serialized as JSON in the Database.
// More specifially, each retention policy has a triplet of
// (project, workflows, job) rules.
//
// To be able to serialize and deserialize the values, we
// are defining the Value() and Scan() methods that will be
// used by GORM to execute the serialization.
type RetentionPolicyRules struct {
	Rules []RetentionPolicyRuleItem `json:"rules"`
}

type RetentionPolicyRuleItem struct {
	Selector string `json:"selector"`
	Age      int    `json:"age"`
}

func (i *RetentionPolicyRuleItem) isMatching(rulePrefix string, path string) bool {
	ismatching, err := doublestar.PathMatch(rulePrefix+i.Selector, path)
	if err != nil {
		return false
	}

	return ismatching
}

func (r RetentionPolicyRules) Value() (driver.Value, error) {
	return json.Marshal(r)
}

func (r *RetentionPolicyRules) Scan(value interface{}) error {
	b, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(b, &r)
}

func (r *RetentionPolicyRules) Validate() error {
	if len(r.Rules) > MaxRetentionPolicyRules {
		return ErrRetentionPolicyTooLong
	}

	for _, rule := range r.Rules {
		if len(rule.Selector) > MaxRetentionPolicySelectorLenght {
			return ErrRetentionPolicySelectorTooLong
		}

		if rule.Age < MinRetentionPolicyAge {
			return ErrRetentionPolicyAgeTooShort
		}
	}

	return nil
}
