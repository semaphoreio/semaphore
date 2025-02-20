// Package summary hold the processors responsible for generating summaries of jobs and pipelines.
package summary

import (
	"errors"
	"log"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/entity"

	"github.com/golang/protobuf/proto"
	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	farm "github.com/semaphoreio/semaphore/velocity/pkg/protos/server_farm.job"
	mqfarm "github.com/semaphoreio/semaphore/velocity/pkg/protos/server_farm.mq.job_state_exchange"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type JobSummarySetupOptions struct {
	InOptions           tackle.Options
	OutOptions          tackle.Options
	FarmClient          service.ServerFarmClient
	ProjectClient       service.ProjectHubClient
	ReportFetcherClient service.ReportFetcherClient
}

type JobSummaryProcessor struct {
	amqp                tackle.Options
	serverFarmClient    service.ServerFarmClient
	projectHubClient    service.ProjectHubClient
	reportFetcherClient service.ReportFetcherClient
}

func (p *JobSummaryProcessor) Process(delivery tackle.Delivery) (err error) {
	defer watchman.BenchmarkWithTags(time.Now(), "velocity.job_summary_worker.execution", []string{})
	defer func() {
		if err != nil {
			_ = watchman.Increment("velocity.job_summary_worker.failure")
		} else {
			_ = watchman.Increment("velocity.job_summary_worker.success")
		}
	}()

	// received pipeline done
	jobDoneEvent := &mqfarm.JobFinished{}

	if err = proto.Unmarshal(delivery.Body(), jobDoneEvent); err != nil {
		log.Printf("failed to unmarshal body %v", err)
		return
	}

	log.Printf("message received: jobId %s", jobDoneEvent.JobId)

	// query serverfarm for pipeline id and project id
	describeResponse, err := p.serverFarmClient.Describe(&farm.DescribeRequest{JobId: jobDoneEvent.JobId})
	if err != nil {
		return
	}

	serverFarmDescribe := entity.NewServerFarmDescribe(describeResponse)
	if !serverFarmDescribe.IsValid() {
		return errors.New("invalid describe response from server farm")
	}

	options := service.ProjectHubDescribeOptions{ProjectID: serverFarmDescribe.ProjectID()}
	projectResponse, err := p.projectHubClient.Describe(&options)
	if err != nil {
		log.Printf("projecthub describe failed %v", err)
		return
	}

	if projectResponse.Project == nil || projectResponse.Project.Spec == nil || len(projectResponse.Project.Spec.ArtifactStoreId) == 0 {
		return errors.New("invalid response from project hub describe")
	}

	summary, err := GetJobSummary(p.reportFetcherClient, projectResponse.Project.Spec.ArtifactStoreId, jobDoneEvent.JobId)
	if err != nil || summary == nil {
		return
	}

	projectID := uuid.MustParse(serverFarmDescribe.ProjectID())
	jobID := uuid.MustParse(jobDoneEvent.JobId)
	pipelineID := serverFarmDescribe.PipelineID()
	jobSummary := summary.ToJobSummary(projectID, pipelineID, jobID)

	if err = entity.SaveJobSummary(&jobSummary); err != nil {
		log.Printf("failed to save job summary %v", err)
		return
	}

	doneEvent := protos.JobSummaryAvailableEvent{
		JobId:     jobDoneEvent.JobId,
		Timestamp: timestamppb.New(time.Now()),
	}

	jobSummaryEvent, err := proto.Marshal(&doneEvent)
	if err != nil {
		return
	}

	params := tackle.PublishParams{
		Body:       jobSummaryEvent,
		AmqpURL:    p.amqp.URL,
		RoutingKey: p.amqp.RoutingKey,
		Exchange:   p.amqp.RemoteExchange,
	}

	return tackle.PublishMessage(&params)
}

func StartJobSummaryProcessor(o *JobSummarySetupOptions) {
	log.Println("starting job summary processor")

	processor := &JobSummaryProcessor{
		amqp:                o.OutOptions,
		serverFarmClient:    o.FarmClient,
		projectHubClient:    o.ProjectClient,
		reportFetcherClient: o.ReportFetcherClient,
	}

	consumer := tackle.NewConsumer()

	err := retry.WithConstantWait("RabbitMQ connection", 20, 2*time.Second, func() error {
		return consumer.Start(&o.InOptions, processor.Process)
	})

	if err != nil {
		log.Fatalf("failed to start job summary processor: %v", err)
	}
}
