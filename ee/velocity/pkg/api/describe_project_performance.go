// Package api holds the grpc api server and endpoint implementation.
package api

import (
	"context"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (p velocityService) DescribeProjectPerformance(ctx context.Context, request *pb.DescribeProjectPerformanceRequest) (*pb.DescribeProjectPerformanceResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.DescribeProjectPerformance")

	lastSuccessfulRunAt := time.Unix(0, 0)
	meanTimeToRecovery := 0.0

	db := database.Conn()

	run, err := entity.FindLastSuccessfulRun(db, uuid.MustParse(request.ProjectId), request.PipelineFileName, request.BranchName)
	if err == nil {
		lastSuccessfulRunAt = run.LastSuccessfulRunAt
	} else {
		log.Printf("DescribeProjectPerformance error: %v, request: %v", err, request)
	}

	meanTimeToRecovery, err = entity.AvgMttr(db, uuid.MustParse(request.ProjectId), request.PipelineFileName, request.BranchName, request.FromDate.AsTime(), request.ToDate.AsTime())
	if err != nil {
		log.Printf("DescribeProjectPerformance error:  %v, request: %v", err, request)
	}

	result := &pb.DescribeProjectPerformanceResponse{
		LastSuccessfulRunAt:       timestamppb.New(lastSuccessfulRunAt),
		MeanTimeToRecoverySeconds: int32(meanTimeToRecovery),
	}

	return result, nil
}
