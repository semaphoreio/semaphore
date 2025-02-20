package summary

import (
	"errors"
	"log"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type PipelineSummaryProcessor struct {
	amqp                tackle.Options
	plumberClient       service.PlumberClient
	projectHubClient    service.ProjectHubClient
	reportFetcherClient service.ReportFetcherClient
}

func (p *PipelineSummaryProcessor) Process(delivery tackle.Delivery) (err error) {
	defer watchman.BenchmarkWithTags(time.Now(), "velocity.pipeline_summary_worker.execution", []string{})
	defer func() {
		if err != nil {
			_ = watchman.Increment("velocity.pipeline_summary_worker.failure")
		} else {
			_ = watchman.Increment("velocity.pipeline_summary_worker.success")
		}
	}()
	// uses pipeline event for now before actual after pipeline event is done
	event := &pb.AfterPipelineEvent{}
	if err = proto.Unmarshal(delivery.Body(), event); err != nil {
		log.Printf("failed to unmarshal body %v", err)
		return
	}

	afterPipeline := entity.NewAfterPipeline(event)

	if afterPipeline.HasEmptyID() {
		return errors.New("missing pipeline identifier")
	}
	log.Println("message received: ppl ", afterPipeline.PipelineID())

	if !afterPipeline.IsDone() {
		return nil
	}

	response, err := p.plumberClient.Describe(&pb.DescribeRequest{PplId: afterPipeline.PipelineID(), Detailed: true})
	if err != nil {
		log.Printf("plumber describe failed %v", err)
		return
	}

	if response.Pipeline == nil || len(response.Pipeline.ProjectId) == 0 || len(response.Pipeline.WfId) == 0 {
		return errors.New("invalid response from plumber describe")
	}

	projectID, err := uuid.Parse(response.Pipeline.ProjectId)
	if err != nil {
		log.Printf("invalid project id, should've been an uuid %v", err)
		return err
	}

	pipelineID, err := uuid.Parse(afterPipeline.PipelineID())
	if err != nil {
		log.Printf("invalid pipeline id, should've been an uuid %v", err)
		return err
	}

	options := service.ProjectHubDescribeOptions{ProjectID: response.Pipeline.ProjectId}
	projectResponse, err := p.projectHubClient.Describe(&options)
	if err != nil {
		log.Printf("projecthub describe failed %v", err)
		return
	}

	if projectResponse.Project == nil || projectResponse.Project.Spec == nil || len(projectResponse.Project.Spec.ArtifactStoreId) == 0 {
		return errors.New("invalid response from project hub describe")
	}

	summary, err := GetWorkflowSummary(p.reportFetcherClient, projectResponse.Project.Spec.ArtifactStoreId, response.Pipeline.WfId, afterPipeline.PipelineID())
	if err != nil || summary == nil {
		return
	}

	pipelineSummary := summary.ToPipelineSummary(projectID, pipelineID)
	if err = entity.SavePipelineSummary(&pipelineSummary); err != nil {
		log.Printf("failed to save pipeline summary %v", err)
		return
	}

	doneEvent := protos.PipelineSummaryAvailableEvent{
		PipelineId: pipelineSummary.PipelineID.String(),
		Timestamp:  timestamppb.New(time.Now()),
	}

	pipelineSummaryEvent, err := proto.Marshal(&doneEvent)
	if err != nil {
		return
	}

	params := tackle.PublishParams{
		Body:       pipelineSummaryEvent,
		AmqpURL:    p.amqp.URL,
		RoutingKey: p.amqp.RoutingKey,
		Exchange:   p.amqp.RemoteExchange,
	}

	return tackle.PublishMessage(&params)
}

// StartPipelineSummaryProcessor
func StartPipelineSummaryProcessor(inOptions, outOptions tackle.Options,
	plumberClient service.PlumberClient, projectClient service.ProjectHubClient, reportFetcherClient service.ReportFetcherClient) {
	log.Println("starting pipeline summary processor")

	processor := &PipelineSummaryProcessor{
		amqp:                outOptions,
		plumberClient:       plumberClient,
		projectHubClient:    projectClient,
		reportFetcherClient: reportFetcherClient,
	}

	consumer := tackle.NewConsumer()

	err := retry.WithConstantWait("RabbitMQ connection", 20, 2*time.Second, func() error {
		return consumer.Start(&inOptions, processor.Process)
	})

	if err != nil {
		log.Fatalf("failed to start pipeline summary processor: %v", err)
	}
}
