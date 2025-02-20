package entity

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
	"gorm.io/gorm"
)

type MetricsDashboardItem struct {
	ID                 uuid.UUID `gorm:"type:uuid;primaryKey;"`
	MetricsDashboardID uuid.UUID
	Name               string
	BranchName         string
	PipelineFileName   string
	Settings           ItemSettings
	InsertedAt         time.Time
	UpdatedAt          time.Time
	Notes              string
}

type ItemSettings struct {
	Metric string
	Goal   string
}

func (m MetricsDashboardItem) ToProto() *pb.DashboardItem {
	return &pb.DashboardItem{
		Id:                 m.ID.String(),
		Name:               m.Name,
		MetricsDashboardId: m.MetricsDashboardID.String(),
		BranchName:         m.BranchName,
		PipelineFileName:   m.PipelineFileName,
		InsertedAt:         timestamppb.New(m.InsertedAt),
		UpdatedAt:          timestamppb.New(m.UpdatedAt),
		Notes:              m.Notes,
		Settings: &pb.DashboardItemSettings{
			Metric: pb.Metric(pb.Metric_value[m.Settings.Metric]),
			Goal:   m.Settings.Goal,
		},
	}
}

func (m *ItemSettings) Value() (driver.Value, error) {
	return json.Marshal(m)
}

func (m *ItemSettings) Scan(value interface{}) error {
	b, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(b, m)
}

func (MetricsDashboardItem) TableName() string {
	return "metrics_dashboard_items"
}

func (m *MetricsDashboardItem) BeforeCreate(_ *gorm.DB) (err error) {
	now := time.Now().UTC()
	if m.ID == uuid.Nil {
		m.ID = uuid.New()
	}
	m.InsertedAt = now
	m.UpdatedAt = now
	return
}

func (m *MetricsDashboardItem) BeforeUpdate(_ *gorm.DB) (err error) {
	m.UpdatedAt = time.Now().UTC()
	return
}

func SaveMetricsDashboardItem(item *MetricsDashboardItem) error {
	query := database.Conn()

	if err := query.Save(item).Error; err != nil {
		if strings.Contains(err.Error(), "duplicate key value violates unique constraint") {
			return fmt.Errorf("metrics dashboard item id must be unique")
		}

		return err
	}

	return nil
}

func UpdateMetricsDashboardItem(id uuid.UUID, name string) error {
	query := database.Conn()
	return query.Model(&MetricsDashboardItem{}).Where("id = ?", id).Update("name", name).Error
}

func DeleteMetricsDashboardItem(id uuid.UUID) error {
	query := database.Conn()
	return query.Delete(&MetricsDashboardItem{ID: id}).Error
}

func UpdateMetricsDashboardItemNotes(id uuid.UUID, notes string) error {
	query := database.Conn()
	return query.Model(&MetricsDashboardItem{}).Where("id = ?", id).Update("notes", notes).Error
}

func DashboardItemFindById(id uuid.UUID) (*MetricsDashboardItem, error) {
	result := &MetricsDashboardItem{}

	query := database.Conn()

	err := query.First(result, "id = ?", id).Error

	return result, err
}
