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

func (p velocityService) ListPipelineFrequencyMetrics(ctx context.Context, request *pb.ListPipelineFrequencyMetricsRequest) (*pb.ListPipelineFrequencyMetricsResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListPipelineFrequencyMetrics")

	if len(request.PipelineFileName) == 0 {
		log.Printf("ListPipelineFrequencyMetrics error: missing pipeline file name, request: %v", request)
		return emptyFreqResult(request), nil
	}

	projectMetrics, err := entity.ListProjectMetricsBy(entity.ProjectMetricsFilter{
		BeginDate:        sqlNullTimeFromPbTimestamp(request.FromDate),
		EndDate:          sqlNullTimeFromPbTimestamp(request.ToDate),
		ProjectId:        uuid.MustParse(request.ProjectId),
		PipelineFileName: request.PipelineFileName,
		BranchName:       request.BranchName,
	})

	if err != nil {
		log.Printf("ListPipelineFrequencyMetrics error: error: %v, request: %v", request, err)
		return nil, err
	}

	switch {
	case request.Aggregate == pb.MetricAggregation_DAILY:
		return frequencyMetricsForDailyAggr(projectMetrics)
	case request.Aggregate == pb.MetricAggregation_RANGE:
		return frequencyMetricsForRangeAggr(projectMetrics, request)
	default:
		return nil, errors.New("unsupported aggregation")
	}
}

func frequencyMetricsForRangeAggr(metrics []entity.ProjectMetrics, request *pb.ListPipelineFrequencyMetricsRequest) (*pb.ListPipelineFrequencyMetricsResponse, error) {
	var result pb.ListPipelineFrequencyMetricsResponse
	result.Metrics = make([]*pb.FrequencyMetric, len(metrics))

	initial := &pb.FrequencyMetric{
		FromDate: request.FromDate,
		ToDate:   request.ToDate,
		AllCount: 0,
	}

	sum := collections.Reduce(metrics, initial, func(accumulator *pb.FrequencyMetric, metric entity.ProjectMetrics) *pb.FrequencyMetric {
		allCount := metric.Metrics.All.Frequency.Count

		return &pb.FrequencyMetric{
			FromDate: accumulator.FromDate,
			ToDate:   accumulator.ToDate,
			AllCount: accumulator.AllCount + allCount,
		}
	})

	result.Metrics = []*pb.FrequencyMetric{sum}
	return &result, nil
}

func frequencyMetricsForDailyAggr(metrics []entity.ProjectMetrics) (*pb.ListPipelineFrequencyMetricsResponse, error) {
	var result pb.ListPipelineFrequencyMetricsResponse

	result.Metrics = collections.Map(metrics, func(metric entity.ProjectMetrics) *pb.FrequencyMetric {
		allCount := metric.Metrics.All.Frequency.Count

		return &pb.FrequencyMetric{
			FromDate: timestamppb.New(metric.CollectedAt),
			ToDate:   timestamppb.New(metric.CollectedAt),
			AllCount: allCount,
		}
	})

	return &result, nil
}

func emptyFreqResult(request *pb.ListPipelineFrequencyMetricsRequest) *pb.ListPipelineFrequencyMetricsResponse {
	zeroMetrics := make([]*pb.FrequencyMetric, 0)
	zero := pb.FrequencyMetric{
		FromDate: request.FromDate,
		ToDate:   request.ToDate,
		AllCount: 0,
	}

	zeroMetrics = append(zeroMetrics, &zero)
	return &pb.ListPipelineFrequencyMetricsResponse{Metrics: zeroMetrics}
}
