// Package aggregator implements the project metrics aggregator.
package aggregator

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/calc"
	"github.com/semaphoreio/semaphore/velocity/pkg/collections"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
)

type ProjectMetricsAggregator struct {
	Name     string
	Queue    tackle.Options
	Consumer *tackle.Consumer
}

func NewProjectMetricsAggregator(readQueue tackle.Options) *ProjectMetricsAggregator {
	return &ProjectMetricsAggregator{
		Name:     "project_metrics_aggregator",
		Consumer: tackle.NewConsumer(),
		Queue:    readQueue,
	}
}

func StartProjectMetrics(readQueue tackle.Options) {
	log.Println("starting project metrics aggregator")

	aggregator := NewProjectMetricsAggregator(readQueue)
	err := retry.WithConstantWait(fmt.Sprintf("Start %s", aggregator.Name), 2, 1*time.Second, func() error {
		return aggregator.Consumer.Start(&readQueue, aggregator.HandleDelivery)
	})

	if err != nil {
		log.Fatalf("failed to start %s", aggregator.Name)
	}
}

func (aggr ProjectMetricsAggregator) Start() error {
	return retry.WithConstantWait(fmt.Sprintf("Start %s", aggr.Name), 2, 1*time.Second, func() error {
		return aggr.Consumer.Start(&aggr.Queue, aggr.HandleDelivery)
	})
}

func (aggr ProjectMetricsAggregator) State() string {
	return aggr.Consumer.State
}

func (aggr ProjectMetricsAggregator) Stop() {
	aggr.Consumer.Stop()
}

func (aggr ProjectMetricsAggregator) HandleDelivery(delivery tackle.Delivery) error {
	defer aggr.benchmark("execution", []string{})

	event, err := aggr.parseMessage(delivery.Body())
	if err != nil {
		log.Printf("parsing body failed %v", err)
		aggr.increment("failure")
		return err
	}

	log.Printf("Received processing event (%s %s %s %s)",
		event.ProjectId,
		event.PipelineFileName,
		event.BranchName,
		event.MetricDay.AsTime().Format("2006-01-02"),
	)

	id, err := uuid.Parse(event.ProjectId)
	if err != nil {
		log.Println("failed to parse project ID")
		return err
	}

	if len(event.PipelineFileName) == 0 {
		log.Println("pipeline file name is empty")
		return fmt.Errorf("pipeline file name is empty")
	}

	key := entity.ProjectMetricsKey{
		ProjectId:   id,
		FileName:    event.PipelineFileName,
		BranchName:  event.BranchName,
		CollectedAt: event.MetricDay.AsTime(),
	}

	exists, err := entity.ProjectMetricsExists(key)
	if err != nil {
		log.Printf("failed to check if project metrics exists %v", err)
		aggr.increment("failure")
		return err
	}

	if exists {
		aggr.increment("success")
		log.Printf("Event already exists (%s %s %s %s)",
			event.ProjectId,
			event.PipelineFileName,
			event.BranchName,
			event.MetricDay.AsTime().Format("2006-01-02"),
		)
		return nil
	}

	//load all values for day
	runs, err := entity.ListPipelineRuns(key.ProjectId, key.CollectedAt, key.FileName, key.BranchName)
	if err != nil {
		log.Printf("failed to fetch runs for project: %s pipeline: %s branch: %s day: %v error %v", key.ProjectId, key.FileName, key.BranchName, key.CollectedAt, err)
		aggr.increment("failure")
		return err
	}

	log.Printf(
		"Loaded %d runs for (%s %s %s %s)",
		len(runs),
		key.ProjectId,
		key.FileName,
		key.BranchName,
		event.MetricDay.AsTime().Format("2006-01-02"),
	)

	if len(runs) == 0 {
		log.Printf("Runs empty (%s %s %s %s)",
			event.ProjectId,
			event.PipelineFileName,
			event.BranchName,
			event.MetricDay.AsTime().Format("2006-01-02"),
		)
		return nil
	}

	projectMetric, err := aggr.calculateMetrics(event, runs)
	if err != nil {
		log.Printf("failed to calculate metrics for project %s at %v - %v", id, event.MetricDay.AsTime(), err)
		aggr.increment("failure")
		return nil
	}

	if len(projectMetric.PipelineFileName) == 0 {
		projectMetric.PipelineFileName = event.PipelineFileName
	}

	//NOTE: Deletion needs to happen at a different date than what was processed
	// because we need to use the pipeline run data more than once, so it is not possible
	// to delete that data before all processing is done.
	if err = entity.SaveProjectMetrics(projectMetric); err != nil {
		log.Printf("failed to save project metrics %v", err)
		aggr.increment("failure")
		return err
	}

	aggr.increment("success")
	log.Printf("Event processed successfully (%s %s %s %s)",
		event.ProjectId,
		event.PipelineFileName,
		event.BranchName,
		event.MetricDay.AsTime().Format("2006-01-02"),
	)

	return nil
}

func (aggr ProjectMetricsAggregator) calculateMetrics(event *pb.CollectPipelineMetricsEvent, runs []entity.PipelineRun) (*entity.ProjectMetrics, error) {
	projectId, err := uuid.Parse(event.ProjectId)
	if err != nil {
		return nil, err
	}

	organizationId, err := uuid.Parse(event.OrganizationId)
	if err != nil {
		return nil, err
	}

	pm := &entity.ProjectMetrics{
		ProjectId:        projectId,
		PipelineFileName: event.PipelineFileName,
		CollectedAt:      event.MetricDay.AsTime(),
		BranchName:       event.BranchName,
		OrganizationId:   organizationId,
	}

	pm.Metrics = calculateMetricForRuns(runs)
	return pm, nil
}

func calculateMetricForRuns(runs []entity.PipelineRun) entity.Metrics {
	passedRuns := collections.Filter(runs, isResult("PASSED"))
	failedRuns := collections.Filter(runs, isResult("FAILED"))

	//Note: All is different from passed + failed
	// It includes stopped runs for calculating frequency.
	return entity.Metrics{
		All:    calculateMetric(runs),
		Passed: calculateMetric(passedRuns),
		Failed: calculateMetric(failedRuns),
	}
}

func calculateMetric(runs []entity.PipelineRun) entity.MetricPoint {
	count := len(runs)

	runs = collections.Filter(runs, func(run entity.PipelineRun) bool { return run.Reason != "USER" && run.Reason != "STRATEGY" })
	stoppedCount := collections.Count(runs, isResult("STOPPED"))
	failedCount := collections.Count(runs, isResult("FAILED"))
	passedCount := collections.Count(runs, isResult("PASSED"))

	accessor := func(run entity.PipelineRun) int32 { return int32(run.DoneAt.Sub(run.RunningAt).Seconds()) }
	min := calc.MinFunc(runs, accessor)
	max := calc.MaxFunc(runs, accessor)
	avg := calc.AverageFunc(runs, accessor)
	median := calc.MedianFunc(runs, accessor)
	stdDev := calc.StdDevFunc(runs, accessor)
	p95 := calc.P95Func(runs, accessor)
	return entity.MetricPoint{
		Frequency: entity.Frequency{
			Count: int32(count),
		},
		Performance: entity.Performance{
			StdDev: stdDev,
			Avg:    avg,
			Median: median,
			Max:    max,
			Min:    min,
			P95:    p95,
		},
		Reliability: entity.Reliability{
			Total:   int32(len(runs)),
			Stopped: int32(stoppedCount),
			Failed:  int32(failedCount),
			Passed:  int32(passedCount),
		},
	}
}

func (aggr ProjectMetricsAggregator) parseMessage(body []byte) (*pb.CollectPipelineMetricsEvent, error) {
	result := &pb.CollectPipelineMetricsEvent{}
	err := proto.Unmarshal(body, result)
	return result, err
}

func (aggr ProjectMetricsAggregator) benchmark(name string, tags []string) {
	metricName := fmt.Sprintf("velocity.%s.%s", aggr.Name, name)
	if err := watchman.BenchmarkWithTags(time.Now(), metricName, tags); err != nil {
		log.Printf("watchman BenchmarkWithTags failed with %v", err)
	}
}

func (aggr ProjectMetricsAggregator) increment(name string) {
	metricName := fmt.Sprintf("velocity.%s.%s", aggr.Name, name)
	if err := watchman.Increment(metricName); err != nil {
		log.Printf("watchman increment failed with %v", err)
	}
}

func isResult(state string) func(run entity.PipelineRun) bool {
	state = strings.ToUpper(state)
	return func(run entity.PipelineRun) bool { return run.Result == state }
}

func isReason(reason string) func(run entity.PipelineRun) bool {
	reason = strings.ToUpper(reason)
	return func(run entity.PipelineRun) bool { return run.Reason == reason }
}
