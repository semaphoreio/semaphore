package entity

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
	"gorm.io/gorm"
)

type MetricsDashboard struct {
	ID             uuid.UUID `gorm:"type:uuid;primaryKey;"`
	Name           string
	ProjectId      uuid.UUID
	OrganizationId uuid.UUID
	InsertedAt     time.Time
	UpdatedAt      time.Time

	Items []MetricsDashboardItem
}

func (MetricsDashboard) TableName() string {
	return "metrics_dashboards"
}

func (r *MetricsDashboard) BeforeCreate(_ *gorm.DB) (err error) {
	now := time.Now().UTC()

	if r.ID == uuid.Nil {
		r.ID = uuid.New()
	}

	r.InsertedAt = now
	r.UpdatedAt = now
	return
}

func (r *MetricsDashboard) BeforeUpdate(_ *gorm.DB) (err error) {
	r.UpdatedAt = time.Now().UTC()
	return
}

func (r *MetricsDashboard) ToProto() *pb.MetricsDashboard {
	dashboardItems := make([]*pb.DashboardItem, 0)

	for _, item := range r.Items {
		dashboardItems = append(dashboardItems, item.ToProto())
	}

	return &pb.MetricsDashboard{
		Id:             r.ID.String(),
		Name:           r.Name,
		ProjectId:      r.ProjectId.String(),
		OrganizationId: r.OrganizationId.String(),
		InsertedAt:     timestamppb.New(r.InsertedAt),
		UpdatedAt:      timestamppb.New(r.InsertedAt),
		Items:          dashboardItems,
	}
}

func SaveMetricsDashboard(dashboard *MetricsDashboard) error {
	query := database.Conn()

	if err := query.Save(dashboard).Error; err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("metrics dashboard id must be unique")
		}

		return err
	}

	return nil
}

func UpdateMetricsDashboard(id uuid.UUID, newName string) error {
	query := database.Conn()

	return query.Model(&MetricsDashboard{}).Where("id = ?", id).Update("name", newName).Error
}

func ListMetricsDashboardsByProject(projectId uuid.UUID) ([]MetricsDashboard, error) {
	result := make([]MetricsDashboard, 0)

	query := database.Conn()

	err := query.Model(&MetricsDashboard{}).
		Where("project_id = ?", projectId).
		Preload("Items").
		Find(&result).Error

	return result, err
}

func ListMetricsDashboards() ([]MetricsDashboard, error) {
	result := make([]MetricsDashboard, 0)

	query := database.Conn()

	err := query.Model(&MetricsDashboard{}).
		Preload("Items").
		Order("inserted_at").
		Find(&result).Error

	return result, err
}

func FindMetricsDashboardById(id uuid.UUID) (*MetricsDashboard, error) {
	result := &MetricsDashboard{}

	query := database.Conn()

	err := query.Table("metrics_dashboards").
		Where("id = ?", id).
		Preload("Items").
		First(result).Error

	return result, err
}

func DeleteMetricsDashboardById(id uuid.UUID) error {
	query := database.Conn()

	return query.Delete(&MetricsDashboard{}, id).Error
}

func DeleteMetricsDashboardsByOrganizationId(organizationId uuid.UUID) error {
	query := database.Conn()

	return query.Where("organization_id = ?", organizationId).Delete(&MetricsDashboard{}).Error
}
