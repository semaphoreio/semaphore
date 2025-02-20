// Package main
package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/semaphoreio/semaphore/velocity/pkg/aggregator"
	"github.com/semaphoreio/semaphore/velocity/pkg/api"
	"github.com/semaphoreio/semaphore/velocity/pkg/collector"
	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/emitter"
	"github.com/semaphoreio/semaphore/velocity/pkg/grpc"
	"github.com/semaphoreio/semaphore/velocity/pkg/options"
	"github.com/semaphoreio/semaphore/velocity/pkg/proc/summary"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"github.com/semaphoreio/semaphore/velocity/pkg/shutdown"
	"github.com/semaphoreio/semaphore/velocity/pkg/watchman"
)

const (
	metricService = "velocity"
)

var (
	metricsNamespace                    = os.Getenv("METRICS_NAMESPACE")
	shouldStartInternalAPI              = os.Getenv("START_INTERNAL_API")
	shouldStartPipelineSummaryWorker    = os.Getenv("START_PIPELINE_SUMMARY_WORKER")
	shouldStartJobSummaryWorker         = os.Getenv("START_JOB_SUMMARY_WORKER")
	shouldStartPipelineDoneCollector    = os.Getenv("START_PIPELINE_DONE_COLLECTOR")
	shouldStartPendingMetricsEmitter    = os.Getenv("START_PENDING_METRICS_EMITTER")
	shouldStartProjectMetricsAggregator = os.Getenv("START_PROJECT_METRICS_AGGREGATOR")
	shouldStartSuperjerryCollector      = os.Getenv("START_SUPERJERRY_COLLECTOR")
)

func runInternalAPI() {
	log.Println("Starting Internal API")
	api.RunServer(50051)
}

func main() {
	ctx := context.Background()

	log.SetFlags(log.Ldate | log.Lmicroseconds | log.Lshortfile)

	watchman.Configure(fmt.Sprintf("%s.%s", metricService, metricsNamespace))

	startInternalAPI()
	startPipelineDoneCollector()
	startPipelineSummaryWorker()
	startJobSummaryWorker()
	startPendingMetricsEmitter()
	startProjectMetricsAggregator()
	startSuperjerryCollector()
	shutdown.Set(ctx)

	log.Println("Velocity is UP.")
	select {}
}

func startProjectMetricsAggregator() {
	if shouldStartProjectMetricsAggregator == "yes" {
		go aggregator.StartProjectMetrics(options.CollectPipelineMetricsDoneEvent())
	}
}

func startPendingMetricsEmitter() {
	if shouldStartPendingMetricsEmitter == "yes" {

		projectHubServiceClient := service.NewProjectHubService(grpc.Conn(config.ProjectHubEndpoint()))

		go emitter.StartPendingMetricsEmitter(
			options.CollectPipelineMetricsDoneEvent(),
			projectHubServiceClient,
			fetchCronTabFor("EMITTER_CRONTAB"),
		)
	}
}

func startPipelineDoneCollector() {
	if shouldStartPipelineDoneCollector == "yes" {
		plumberServiceClient := service.NewPlumberService(grpc.Conn(config.PlumberEndpoint()))
		projectHubServiceClient := service.NewProjectHubService(grpc.Conn(config.ProjectHubEndpoint()))
		pipelineDoneOptions := options.PipelineDoneEvent()

		go collector.StartPipelineDone(&pipelineDoneOptions, projectHubServiceClient, plumberServiceClient)
	}
}

func startSuperjerryCollector() {
	if shouldStartSuperjerryCollector == "yes" {
		tackleOptions := options.SuperjerryJobSummary()
		cacheService := service.NewCacheService()

		artifactHubServiceClient := service.NewArtifactHubService(grpc.Conn(config.ArtifactHubEndpoint()))
		projectHubServiceClient := service.NewProjectHubService(grpc.Conn(config.ProjectHubEndpoint()))
		serverFarmClient := service.NewServerFarm(grpc.Conn(config.ServerFarmEndpoint()))
		reportFetcherClient := service.NewReportFetcher(artifactHubServiceClient)
		featureHubClient := service.NewFeatureHubService(
			config.FeatureHubEndpoint(),
			cacheService,
		)

		superjerryClient := service.NewSuperjerryService(grpc.ConnWithMaxMsgSize(config.SuperjerryEndpoint()))

		go collector.StartSuperjerryCollector(
			&tackleOptions,
			projectHubServiceClient,
			serverFarmClient,
			featureHubClient,
			reportFetcherClient,
			superjerryClient,
		)
	}
}

func startInternalAPI() {
	if shouldStartInternalAPI == "yes" {
		go runInternalAPI()
	}
}

func startPipelineSummaryWorker() {
	if shouldStartPipelineSummaryWorker == "yes" {
		plumberServiceClient := service.NewPlumberService(grpc.Conn(config.PlumberEndpoint()))
		projectHubServiceClient := service.NewProjectHubService(grpc.Conn(config.ProjectHubEndpoint()))
		artifactHubServiceClient := service.NewArtifactHubService(grpc.Conn(config.ArtifactHubEndpoint()))
		reportFetcherClient := service.NewReportFetcher(artifactHubServiceClient)

		go summary.StartPipelineSummaryProcessor(
			options.AfterPipelineDoneEvent(),
			options.PipelineSummaryDone(),
			plumberServiceClient,
			projectHubServiceClient,
			reportFetcherClient,
		)
	}
}

func startJobSummaryWorker() {
	if shouldStartJobSummaryWorker == "yes" {
		serverFarmClient := service.NewServerFarm(grpc.Conn(config.ServerFarmEndpoint()))
		projectHubServiceClient := service.NewProjectHubService(grpc.Conn(config.ProjectHubEndpoint()))
		artifactHubServiceClient := service.NewArtifactHubService(grpc.Conn(config.ArtifactHubEndpoint()))
		reportFetcherClient := service.NewReportFetcher(artifactHubServiceClient)

		go summary.StartJobSummaryProcessor(&summary.JobSummarySetupOptions{
			InOptions:           options.JobSummaryJobFinished(),
			OutOptions:          options.JobSummaryDone(),
			FarmClient:          serverFarmClient,
			ProjectClient:       projectHubServiceClient,
			ReportFetcherClient: reportFetcherClient,
		})
	}
}

func fetchCronTabFor(key string) (crontab string) {
	crontab, found := os.LookupEnv(key)
	if !found {
		crontab = "0 */6 * * *" // every 6th hour
	}
	return
}
