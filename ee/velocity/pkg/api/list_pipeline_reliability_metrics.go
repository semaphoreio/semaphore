package api

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/collections"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (p velocityService) ListPipelineReliabilityMetrics(ctx context.Context, request *pb.ListPipelineReliabilityMetricsRequest) (*pb.ListPipelineReliabilityMetricsResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListPipelineReliabilityMetrics")

	if len(request.PipelineFileName) == 0 {
		log.Printf("ListPipelineReliabilityMetrics error: missing pipeline file name, request: %v", request)
		return emptyReliabResult(request), nil
	}

	projectMetrics, err := entity.ListProjectMetricsBy(entity.ProjectMetricsFilter{
		BeginDate:        sqlNullTimeFromPbTimestamp(request.FromDate),
		EndDate:          sqlNullTimeFromPbTimestamp(request.ToDate),
		ProjectId:        uuid.MustParse(request.ProjectId),
		PipelineFileName: request.PipelineFileName,
		BranchName:       request.BranchName,
	})

	if err != nil {
		log.Printf("ListPipelineReliabilityMetrics error: %v, request: %v", request, err)
		return nil, err
	}

	switch {
	case request.Aggregate == pb.MetricAggregation_DAILY:
		return reliabilityMetricsForDailyAggr(projectMetrics)
	case request.Aggregate == pb.MetricAggregation_RANGE:
		return reliabilityMetricsForRangeAggr(projectMetrics, request)
	default:
		return nil, errors.New("unsupported aggregation")
	}
}

func reliabilityMetricsForDailyAggr(metrics []entity.ProjectMetrics) (*pb.ListPipelineReliabilityMetricsResponse, error) {
	var result pb.ListPipelineReliabilityMetricsResponse

	result.Metrics = collections.Map(metrics, func(metric entity.ProjectMetrics) *pb.ReliabilityMetric {
		allCount := metric.Metrics.All.Reliability.Total
		passedCount := metric.Metrics.All.Reliability.Passed
		failedCount := metric.Metrics.All.Reliability.Failed + metric.Metrics.All.Reliability.Stopped

		return &pb.ReliabilityMetric{
			FromDate:    timestamppb.New(metric.CollectedAt),
			ToDate:      timestamppb.New(metric.CollectedAt),
			AllCount:    allCount,
			PassedCount: passedCount,
			FailedCount: failedCount,
		}
	})

	return &result, nil
}

func reliabilityMetricsForRangeAggr(metrics []entity.ProjectMetrics, request *pb.ListPipelineReliabilityMetricsRequest) (*pb.ListPipelineReliabilityMetricsResponse, error) {
	var result pb.ListPipelineReliabilityMetricsResponse
	result.Metrics = make([]*pb.ReliabilityMetric, len(metrics))

	initial := &pb.ReliabilityMetric{
		FromDate:    request.FromDate,
		ToDate:      request.ToDate,
		AllCount:    0,
		PassedCount: 0,
		FailedCount: 0,
	}

	sum := collections.Reduce(metrics, initial, func(accumulator *pb.ReliabilityMetric, metric entity.ProjectMetrics) *pb.ReliabilityMetric {
		allCount := metric.Metrics.All.Reliability.Total
		passedCount := metric.Metrics.All.Reliability.Passed
		failedCount := metric.Metrics.All.Reliability.Failed + metric.Metrics.All.Reliability.Stopped

		return &pb.ReliabilityMetric{
			FromDate:    accumulator.FromDate,
			ToDate:      accumulator.ToDate,
			AllCount:    accumulator.AllCount + allCount,
			PassedCount: accumulator.PassedCount + passedCount,
			FailedCount: accumulator.FailedCount + failedCount,
		}
	})

	result.Metrics = []*pb.ReliabilityMetric{sum}

	return &result, nil
}

func emptyReliabResult(request *pb.ListPipelineReliabilityMetricsRequest) *pb.ListPipelineReliabilityMetricsResponse {

	zeroMetrics := make([]*pb.ReliabilityMetric, 0)
	zero := pb.ReliabilityMetric{
		FromDate:    request.FromDate,
		ToDate:      request.ToDate,
		AllCount:    0,
		PassedCount: 0,
		FailedCount: 0,
	}

	zeroMetrics = append(zeroMetrics, &zero)

	return &pb.ListPipelineReliabilityMetricsResponse{
		Metrics: zeroMetrics,
	}
}
