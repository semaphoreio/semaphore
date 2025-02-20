package api

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/golang/protobuf/ptypes/timestamp"
	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/calc"
	"github.com/semaphoreio/semaphore/velocity/pkg/collections"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (p velocityService) ListPipelinePerformanceMetrics(ctx context.Context, request *pb.ListPipelinePerformanceMetricsRequest) (*pb.ListPipelinePerformanceMetricsResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.ListPipelinePerformanceMetrics")

	if len(request.PipelineFileName) == 0 {
		log.Printf("ListPipelinePerformanceMetrics error: missing pipeline file name, request: %v", request)
		return emptyPerfResult(request), nil
	}

	projectMetrics, err := entity.ListProjectMetricsBy(entity.ProjectMetricsFilter{
		BeginDate:        sqlNullTimeFromPbTimestamp(request.FromDate),
		EndDate:          sqlNullTimeFromPbTimestamp(request.ToDate),
		ProjectId:        uuid.MustParse(request.ProjectId),
		PipelineFileName: request.PipelineFileName,
		BranchName:       request.BranchName,
	})

	if err != nil {
		log.Printf("ListPipelinePerformanceMetrics error: error: %v, request: %v", request, err)
		return nil, err
	}

	switch {
	case request.Aggregate == pb.MetricAggregation_DAILY:
		return performanceMetricsForDailyAggr(projectMetrics)
	case request.Aggregate == pb.MetricAggregation_RANGE:
		return performanceMetricsForRangeAggr(projectMetrics, request)
	default:
		return nil, errors.New("unsupported aggregation")
	}
}

func performanceMetricsForDailyAggr(projectMetrics []entity.ProjectMetrics) (*pb.ListPipelinePerformanceMetricsResponse, error) {
	allMetrics := make([]*pb.PerformanceMetric, 0)
	passedMetrics := make([]*pb.PerformanceMetric, 0)
	failedMetrics := make([]*pb.PerformanceMetric, 0)

	//refactor
	for _, metric := range projectMetrics {
		metricPointAll := metric.Metrics.All
		metricPointPassed := metric.Metrics.Passed
		metricPointFailed := metric.Metrics.Failed

		allMetrics = append(allMetrics, &pb.PerformanceMetric{
			FromDate:      timestamppb.New(metric.CollectedAt),
			ToDate:        timestamppb.New(metric.CollectedAt),
			Count:         metricPointAll.Frequency.Count,
			MeanSeconds:   metricPointAll.Performance.Avg,
			MedianSeconds: metricPointAll.Performance.Median,
			MinSeconds:    metricPointAll.Performance.Min,
			MaxSeconds:    metricPointAll.Performance.Max,
			StdDevSeconds: metricPointAll.Performance.StdDev,
			P95Seconds:    metricPointAll.Performance.P95,
		})

		passedMetrics = append(passedMetrics, &pb.PerformanceMetric{
			FromDate:      timestamppb.New(metric.CollectedAt),
			ToDate:        timestamppb.New(metric.CollectedAt),
			Count:         metricPointPassed.Frequency.Count,
			MeanSeconds:   metricPointPassed.Performance.Avg,
			MedianSeconds: metricPointPassed.Performance.Median,
			MinSeconds:    metricPointPassed.Performance.Min,
			MaxSeconds:    metricPointPassed.Performance.Max,
			StdDevSeconds: metricPointPassed.Performance.StdDev,
			P95Seconds:    metricPointPassed.Performance.P95,
		})

		failedMetrics = append(failedMetrics, &pb.PerformanceMetric{
			FromDate:      timestamppb.New(metric.CollectedAt),
			ToDate:        timestamppb.New(metric.CollectedAt),
			Count:         metricPointFailed.Frequency.Count,
			MeanSeconds:   metricPointFailed.Performance.Avg,
			MedianSeconds: metricPointFailed.Performance.Median,
			MinSeconds:    metricPointFailed.Performance.Min,
			MaxSeconds:    metricPointFailed.Performance.Max,
			StdDevSeconds: metricPointFailed.Performance.StdDev,
			P95Seconds:    metricPointFailed.Performance.P95,
		})

	}

	return &pb.ListPipelinePerformanceMetricsResponse{
		AllMetrics:    allMetrics,
		PassedMetrics: passedMetrics,
		FailedMetrics: failedMetrics,
	}, nil
}

func performanceMetricsForRangeAggr(projectMetrics []entity.ProjectMetrics, request *pb.ListPipelinePerformanceMetricsRequest) (*pb.ListPipelinePerformanceMetricsResponse, error) {
	branchMetrics := collections.Map(projectMetrics, func(p entity.ProjectMetrics) entity.Metrics {
		return p.Metrics
	})

	allBranchMetrics := collections.Filter(branchMetrics, func(p entity.Metrics) bool {
		return p.All.Frequency.Count > 0
	})

	passedBranchMetrics := collections.Filter(branchMetrics, func(p entity.Metrics) bool {
		return p.Passed.Frequency.Count > 0
	})

	failedBranchMetrics := collections.Filter(branchMetrics, func(p entity.Metrics) bool {
		return p.Failed.Frequency.Count > 0
	})

	allAvg := calc.AverageFunc(allBranchMetrics, func(m entity.Metrics) int32 {
		return m.All.Performance.Avg
	})

	allStdDev := calc.AverageFunc(allBranchMetrics, func(m entity.Metrics) int32 {
		return m.All.Performance.StdDev
	})

	passedAvg := calc.AverageFunc(passedBranchMetrics, func(m entity.Metrics) int32 {
		return m.Passed.Performance.Avg
	})
	passedStdDev := calc.AverageFunc(passedBranchMetrics, func(m entity.Metrics) int32 {
		return m.Passed.Performance.StdDev
	})

	failedAvg := calc.AverageFunc(failedBranchMetrics, func(m entity.Metrics) int32 {
		return m.Failed.Performance.Avg
	})

	failedStdDev := calc.AverageFunc(failedBranchMetrics, func(m entity.Metrics) int32 {
		return m.Failed.Performance.StdDev
	})

	response := &pb.ListPipelinePerformanceMetricsResponse{
		AllMetrics:    buildAvgResponse(request.FromDate, request.ToDate, allAvg, allStdDev),
		PassedMetrics: buildAvgResponse(request.FromDate, request.ToDate, passedAvg, passedStdDev),
		FailedMetrics: buildAvgResponse(request.FromDate, request.ToDate, failedAvg, failedStdDev),
	}

	return response, nil
}

func buildAvgResponse(from, to *timestamp.Timestamp, avg int32, stdDev int32) []*pb.PerformanceMetric {
	return []*pb.PerformanceMetric{{
		FromDate:      from,
		ToDate:        to,
		MeanSeconds:   avg,
		StdDevSeconds: stdDev,
	}}
}

func emptyPerfResult(request *pb.ListPipelinePerformanceMetricsRequest) *pb.ListPipelinePerformanceMetricsResponse {
	allMetrics := make([]*pb.PerformanceMetric, 0)
	passedMetrics := make([]*pb.PerformanceMetric, 0)
	failedMetrics := make([]*pb.PerformanceMetric, 0)

	zero := pb.PerformanceMetric{
		FromDate:      request.FromDate,
		ToDate:        request.ToDate,
		Count:         0,
		MeanSeconds:   0,
		MedianSeconds: 0,
		MinSeconds:    0,
		MaxSeconds:    0,
		StdDevSeconds: 0,
		P95Seconds:    0,
	}

	allMetrics = append(allMetrics, &zero)
	passedMetrics = append(passedMetrics, &zero)
	failedMetrics = append(failedMetrics, &zero)

	return &pb.ListPipelinePerformanceMetricsResponse{
		AllMetrics:    allMetrics,
		PassedMetrics: passedMetrics,
		FailedMetrics: failedMetrics,
	}
}
