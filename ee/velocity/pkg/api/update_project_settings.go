package api

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

var (
	ErrInvalidRequestMissingSettings = errors.New("invalid request, missing settings")
)

func (p velocityService) UpdateProjectSettings(ctx context.Context, request *pb.UpdateProjectSettingsRequest) (*pb.UpdateProjectSettingsResponse, error) {
	if err := watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.UpdateProjectSettings"); err != nil {
		log.Printf("watchman beanchmark failed with error %v", err)
		err = nil
	}

	if request.Settings == nil {
		log.Printf("UpdateProjectSettings error: %v, request: %+v", ErrInvalidRequestMissingSettings, request)
		return nil, ErrInvalidRequestMissingSettings
	}

	settings, err := entity.UpdateProjectSettings(request.ProjectId, request.Settings)
	if err != nil {
		log.Printf("UpdateProjectSettings error: %v, request: %+v", err, request)
		return nil, err
	}
	response := &pb.UpdateProjectSettingsResponse{
		Settings: settings.ToProto(),
	}
	return response, nil
}
