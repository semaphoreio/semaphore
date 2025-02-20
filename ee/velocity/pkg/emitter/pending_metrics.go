// Package emitter holds the emitter service implementation.
package emitter

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/go-co-op/gocron"
	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/protos/projecthub"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type PendingMetricsEmitter struct {
	Name             string
	crontab          string
	options          tackle.Options
	projectHubClient *service.ProjectHubGrpcClient
}

func NewPendingMetricsEmitter(options tackle.Options, projectHubServiceClient *service.ProjectHubGrpcClient, crontab string) *PendingMetricsEmitter {
	return &PendingMetricsEmitter{
		Name:             "pending_metrics_emitter",
		crontab:          crontab,
		options:          options,
		projectHubClient: projectHubServiceClient,
	}
}

func StartPendingMetricsEmitter(options tackle.Options, projectHubServiceClient *service.ProjectHubGrpcClient, crontab string) {
	emitter := NewPendingMetricsEmitter(options, projectHubServiceClient, crontab)
	if err := emitter.Start(); HasError(err) {
		log.Fatalf("pending metrics emitter failed to start, %v", err)
	}
}

func (emitter *PendingMetricsEmitter) Start() (err error) {
	scheduler := gocron.
		NewScheduler(time.UTC).
		SingletonMode().
		Cron(emitter.crontab).
		StartImmediately()

	log.Printf(`Starting emitter service with "%s" crontab`, emitter.crontab)

	if _, err = scheduler.Do(emitter.PublishPendingMetrics); HasError(err) {
		log.Fatalf("pending metrics emitter failed to start, %v", err)
		return err
	}

	scheduler.StartBlocking()
	return
}

func (emitter *PendingMetricsEmitter) PublishPendingMetrics() (err error) {
	log.Println(`Starting database cleanup`)
	CleanDatabase()
	log.Println(`Finished database cleanup`)

	wg := new(sync.WaitGroup)
	workerCount := 20

	pendingMetrics, err := entity.ListPendingMetrics()
	if HasError(err) {
		log.Printf("listing pending metrics failed %v", err)
		return err
	}

	log.Printf(`Publishing %d pending metrics with %d workers`, len(pendingMetrics), workerCount)

	jobs := make(chan entity.PendingMetric, workerCount)

	for i := 0; i < workerCount; i++ {
		go emitter.emitMetric(wg, jobs)
	}

	wg.Add(len(pendingMetrics))
	for _, pendingMetric := range pendingMetrics {
		jobs <- pendingMetric
	}
	close(jobs)

	projectSettings, err := entity.ListProjectSettings()
	if NoError(err) {
		publishProjectSettings(projectSettings, emitter, wg)
	}

	customDashboards, err := entity.ListMetricsDashboards()
	if NoError(err) {
		publishCustomDashboards(customDashboards, emitter, wg)
	}
	log.Printf(`Finished publishing %d pending metrics`, len(pendingMetrics))
	wg.Wait()

	return nil
}

func CleanDatabase() {
	rowsAffected, err := entity.DeletePipelineRunsOlderThan31Days()
	if NoError(err) {
		incrementByForTable("pipeline_runs", int(rowsAffected.Int64))
	}
	rowsAffected, err = entity.DeleteProjectMetricsOlderThanSixMonths()
	if NoError(err) {
		incrementByForTable("project_metrics", int(rowsAffected.Int64))
	}

	rowsAffected, err = entity.DeleteProjectMTTROlderThanOneYear()
	if NoError(err) {
		incrementByForTable("project_mttr", int(rowsAffected.Int64))
	}

	rowsAffected, err = entity.DeleteProjectLastSuccessfulRunOlderThanOneYear()
	if NoError(err) {
		incrementByForTable("project_last_successful_run", int(rowsAffected.Int64))
	}

}

func (emitter *PendingMetricsEmitter) emitMetric(wg *sync.WaitGroup, jobs <-chan entity.PendingMetric) {
	for pendingMetric := range jobs {
		emitter.processMetric(pendingMetric)
		wg.Done()
	}
}

func (emitter *PendingMetricsEmitter) processMetric(pendingMetric entity.PendingMetric) {
	project, err := emitter.describeProject(pendingMetric.ProjectId)
	if HasError(err) {
		log.Printf("describing project %s failed %v", pendingMetric.ProjectId, err)
		return
	}

	orgID := ""
	if project != nil && project.Project != nil && project.Project.Metadata != nil {
		orgID = project.Project.Metadata.OrgId
	}

	// emit event for CI branch name
	ciBranch := getCIBranchName(project, pendingMetric.ProjectId.String())
	err = emitter.emit(pendingMetric, orgID, ciBranch)
	if HasError(err) {
		emitter.increment("publish_message", []string{"fail"})
		log.Printf("failed to emit message %v for CI branch (%s) with error %v", pendingMetric, ciBranch, err)
		return
	}

	emitter.increment("publish_message", []string{"success"})

	// emit event for CD branch name
	cdBranch := getCDBranchName(project, pendingMetric.ProjectId.String())
	err = emitter.emit(pendingMetric, orgID, cdBranch)
	if HasError(err) {
		emitter.increment("publish_message", []string{"fail"})
		log.Printf("failed to emit message %v for CD branch (%s) with error %v", pendingMetric, cdBranch, err)
		return
	}

	emitter.increment("publish_message", []string{"success"})

	// emit event for '' branch name (all branches)
	err = emitter.emit(pendingMetric, orgID, "")
	if HasError(err) {
		emitter.increment("publish_message", []string{"fail"})
		log.Printf("failed to emit message %v for all branches with error %v", pendingMetric, err)
		return
	}

	emitter.increment("publish_message", []string{"success"})
}

func (emitter *PendingMetricsEmitter) emit(pendingMetric entity.PendingMetric, orgID, branchName string) error {
	defer emitter.benchmark("emit", []string{})
	message, err := emitter.buildMessage(pendingMetric, orgID, branchName)
	if HasError(err) {
		return err
	}

	if err = emitter.publishMessage(message); HasError(err) {
		return err
	}

	log.Printf("Published pending metric (%s %s %s %s %d )",
		pendingMetric.ProjectId,
		pendingMetric.PipelineFileName,
		branchName,
		pendingMetric.DoneAt.Format("2006-01-02"),
		pendingMetric.PipelinesCount)

	return nil
}

func (emitter *PendingMetricsEmitter) publishMessage(message []byte) (err error) {
	params := &tackle.PublishParams{
		Body:       message,
		AmqpURL:    emitter.options.URL,
		RoutingKey: emitter.options.RoutingKey,
		Exchange:   emitter.options.RemoteExchange,
	}

	if err = tackle.PublishMessage(params); HasError(err) {
		log.Printf("failed to publish message, %v", err)
		return
	}

	return
}

func (emitter *PendingMetricsEmitter) buildMessage(pendingMetric entity.PendingMetric, orgID string, branchName string) (message []byte, err error) {
	if len(orgID) == 0 {
		log.Printf("organizationId is empty, projectId: %s", pendingMetric.ProjectId.String())
		return nil, fmt.Errorf("organizationId is empty, projectId: %s", pendingMetric.ProjectId.String())
	}

	if len(pendingMetric.PipelineFileName) == 0 {
		log.Printf("pipeline file name is empty, projectId: %s", pendingMetric.ProjectId.String())
		return nil, fmt.Errorf("pipeline file name is empty, projectId: %s", pendingMetric.ProjectId.String())
	}

	collectPipelineMetricsEvent := protos.CollectPipelineMetricsEvent{
		ProjectId:        pendingMetric.ProjectId.String(),
		PipelineFileName: pendingMetric.PipelineFileName,
		MetricDay:        timestamppb.New(pendingMetric.DoneAt),
		Timestamp:        timestamppb.New(time.Now()),
		OrganizationId:   orgID,
		BranchName:       branchName,
	}

	message, err = proto.Marshal(&collectPipelineMetricsEvent)
	if HasError(err) {
		log.Printf("failed to marshal data, %v", err)
		return
	}

	return
}

func getCIBranchName(projectResponse *projecthub.DescribeResponse, projectId string) string {

	settings, err := entity.FindProjectSettingsByProjectId(projectId)
	if NoError(err) && settings.HasCiBranch() {
		return settings.CiBranchName
	}

	if projectResponse != nil &&
		projectResponse.Project != nil &&
		projectResponse.Project.Spec != nil &&
		projectResponse.Project.Spec.Repository != nil &&
		len(projectResponse.Project.Spec.Repository.DefaultBranch) > 0 {

		return projectResponse.Project.Spec.Repository.DefaultBranch
	}

	log.Printf("missing default branch for project %s", projectId)
	return "main"
}

func getCDBranchName(projectResponse *projecthub.DescribeResponse, projectId string) string {

	settings, err := entity.FindProjectSettingsByProjectId(projectId)
	if NoError(err) && settings.HasCdBranch() {
		return settings.CdBranchName
	}

	if projectResponse != nil &&
		projectResponse.Project != nil &&
		projectResponse.Project.Spec != nil &&
		projectResponse.Project.Spec.Repository != nil &&
		len(projectResponse.Project.Spec.Repository.DefaultBranch) > 0 {

		return projectResponse.Project.Spec.Repository.DefaultBranch
	}

	log.Printf("missing default branch for project %s", projectId)
	return "main"
}

func (emitter *PendingMetricsEmitter) describeProject(projectId uuid.UUID) (projectResponse *projecthub.DescribeResponse, err error) {
	options := service.ProjectHubDescribeOptions{ProjectID: projectId.String()}

	projectResponse, err = emitter.projectHubClient.Describe(&options)
	if HasError(err) {
		log.Printf("projecthub describe failed %v", err)
		return
	}

	return
}

func (emitter *PendingMetricsEmitter) benchmark(name string, tags []string) {
	metricName := fmt.Sprintf("velocity.%s.%s", emitter.Name, name)
	if err := watchman.BenchmarkWithTags(time.Now(), metricName, tags); err != nil {
		log.Printf("watchman BenchmarkWithTags failed with %v", err)
	}
}

func (emitter *PendingMetricsEmitter) increment(name string, tags []string) {
	metricName := fmt.Sprintf("velocity.%s.%s", emitter.Name, name)
	if err := watchman.IncrementWithTags(metricName, tags); err != nil {
		log.Printf("watchman IncrementWithTags failed with %v", err)
	}
}

func incrementByForTable(tableName string, value int) {
	metricName := fmt.Sprintf("velocity.deletion.%s", tableName)
	if err := watchman.IncrementBy(metricName, value); err != nil {
		log.Printf("watchman IncrementBy failed with %v", err)
	}
}

func NoError(e error) bool {
	return e == nil
}

func HasError(e error) bool {
	return e != nil
}
