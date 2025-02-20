package api

import (
	"database/sql"

	"github.com/semaphoreio/semaphore/velocity/pkg/service"

	"github.com/golang/protobuf/ptypes/timestamp"

	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
)

type velocityService struct {
	projectHub *service.ProjectHubGrpcClient
}

func NewVelocityService(projectHub *service.ProjectHubGrpcClient) pb.PipelineMetricsServiceServer {
	return &velocityService{projectHub: projectHub}
}

func sqlNullTimeFromPbTimestamp(t *timestamp.Timestamp) sql.NullTime {
	if t != nil && t.IsValid() {
		return sql.NullTime{
			Time:  t.AsTime(),
			Valid: true,
		}
	}

	return sql.NullTime{}
}
