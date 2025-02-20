package api

import (
	"context"
	"errors"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"gorm.io/gorm"
)

func (p velocityService) DescribeProjectSettings(ctx context.Context, request *pb.DescribeProjectSettingsRequest) (*pb.DescribeProjectSettingsResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.DescribeProjectSettings")
	ps, err := entity.FindProjectSettingsByProjectId(request.ProjectId)
	if err != nil {
		if isNotFound(err) {
			return &pb.DescribeProjectSettingsResponse{Settings: &pb.Settings{}}, nil
		}
		return nil, err
	}

	return &pb.DescribeProjectSettingsResponse{Settings: ps.ToProto()}, nil
}

func isNotFound(err error) bool {
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return true
	}
	return false
}
