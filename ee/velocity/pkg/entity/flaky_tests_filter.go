package entity

import (
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
	"gorm.io/gorm"
)

type FlakyTestsFilter struct {
	ID             uuid.UUID `gorm:"type:uuid;primaryKey;"`
	ProjectID      uuid.UUID
	OrganizationId uuid.UUID
	Name           string
	Value          string
	InsertedAt     time.Time
	UpdatedAt      time.Time
}

func (FlakyTestsFilter) TableName() string {
	return "flaky_tests_filters"
}

func (f *FlakyTestsFilter) BeforeCreate(_ *gorm.DB) (err error) {
	now := time.Now().UTC()

	if f.ID == uuid.Nil {
		f.ID = uuid.New()
	}

	if f.InsertedAt.IsZero() {
		f.InsertedAt = now
	}
	f.UpdatedAt = now
	return
}

func (f *FlakyTestsFilter) ToProto() *pb.FlakyTestsFilter {
	return &pb.FlakyTestsFilter{
		Id:             f.ID.String(),
		ProjectId:      f.ProjectID.String(),
		OrganizationId: f.OrganizationId.String(),
		InsertedAt:     timestamppb.New(f.InsertedAt),
		UpdatedAt:      timestamppb.New(f.UpdatedAt),
		Name:           f.Name,
		Value:          f.Value,
	}
}

// ListFlakyTestsFiltersFor returns all flaky tests filters for a given project
// parameters: projectId - the project id
func ListFlakyTestsFiltersFor(projectId uuid.UUID) ([]FlakyTestsFilter, error) {
	result := make([]FlakyTestsFilter, 0)

	query := database.Conn()

	err := query.Model(&FlakyTestsFilter{}).
		Where("project_id = ?", projectId).
		Order("inserted_at asc").
		Find(&result).Error

	return result, err
}

// CreateFlakyTestsFilter creates a new flaky tests filter
// parameters: filter - the filter to create
func CreateFlakyTestsFilter(filter *FlakyTestsFilter) error {
	query := database.Conn()

	return query.Create(filter).Error
}

// DeleteFlakyTestsFilter deletes a flaky tests filter
// parameters: filter id - id of filter to delete
func DeleteFlakyTestsFilter(filterId uuid.UUID) error {
	query := database.Conn()

	return query.Delete(&FlakyTestsFilter{}, filterId).Error
}

func UpdateFlakyTestsFilter(filter *FlakyTestsFilter) error {
	query := database.Conn()

	return query.Model(filter).
		UpdateColumns(map[string]interface{}{"name": filter.Name, "value": filter.Value}).Error
}

func InitializeFlakyTestsFilters(projectId uuid.UUID, organizationId uuid.UUID) ([]FlakyTestsFilter, error) {
	query := database.Conn()
	now := time.Now()
	filters := []FlakyTestsFilter{
		{
			ProjectID:      projectId,
			OrganizationId: organizationId,
			Name:           "Current 30 days",
			Value:          "@is.resolved:false @date.from:now-30d",
			InsertedAt:     now,
			UpdatedAt:      now,
		},
		{
			ProjectID:      projectId,
			OrganizationId: organizationId,
			Name:           "Previous 30 days",
			Value:          "@is.resolved:false @date.from:now-60d @date.to:now-30d",
			InsertedAt:     now.Add(1 * time.Second),
			UpdatedAt:      now.Add(1 * time.Second),
		},
		{
			ProjectID:      projectId,
			OrganizationId: organizationId,
			Name:           "Current 90 days",
			Value:          "@is.resolved:false @date.from:now-90d",
			InsertedAt:     now.Add(2 * time.Second),
			UpdatedAt:      now.Add(2 * time.Second),
		},
		{
			ProjectID:      projectId,
			OrganizationId: organizationId,
			Name:           "Master branch only",
			Value:          "@is.resolved:false @git.branch:master @date.from:now-60d",
			InsertedAt:     now.Add(3 * time.Second),
			UpdatedAt:      now.Add(3 * time.Second),
		},
		{
			ProjectID:      projectId,
			OrganizationId: organizationId,
			Name:           "More than 10 disruptions",
			Value:          "@is.resolved:false @date.from:now-90d @metric.disruptions:>10",
			InsertedAt:     now.Add(4 * time.Second),
			UpdatedAt:      now.Add(4 * time.Second),
		},
	}

	err := query.Create(&filters).Error

	return filters, err
}
