// Package collector holds the pipeline done collector.
package collector

import (
	"errors"
	"log"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
)

const (
	ConnectionRetries           = 20
	ConnectionRetryWaitDuration = 2 * time.Second
)

type PipelineDone struct {
	PlumberClient    service.PlumberClient
	ProjectHubClient service.ProjectHubClient
}

func StartPipelineDone(options *tackle.Options, projectHubClient service.ProjectHubClient, plumberClient service.PlumberClient) {
	log.Println("starting pipeline done collector")
	collector := PipelineDone{
		PlumberClient:    plumberClient,
		ProjectHubClient: projectHubClient,
	}

	consumer := tackle.NewConsumer()

	err := retry.WithConstantWait("RabbitMQ conn", ConnectionRetries, ConnectionRetryWaitDuration, func() error {
		return consumer.Start(options, collector.Collect)
	})

	if err != nil {
		log.Fatalf("err starting pipeline done collector, %v", err)
	}
}

func (d *PipelineDone) Collect(delivery tackle.Delivery) (err error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_done_collector.execution")
	defer func() {
		if err != nil {
			_ = watchman.Increment("velocity.pipeline_done_collector.failure")
		} else {
			_ = watchman.Increment("velocity.pipeline_done_collector.success")
		}
	}()

	pipelineEvent := &pb.PipelineEvent{}
	err = proto.Unmarshal(delivery.Body(), pipelineEvent)
	if err != nil {
		return
	}
	log.Println("message received: ppl ", pipelineEvent.PipelineId)

	if len(pipelineEvent.PipelineId) == 0 {
		return errors.New("missing pipeline identifier")
	}

	in := pb.DescribeRequest{
		PplId:    pipelineEvent.PipelineId,
		Detailed: true,
	}

	describeResponse, err := d.PlumberClient.Describe(&in)
	if err != nil {
		return
	}

	if describeResponse == nil {
		log.Printf("failed to retrieve describe from plumber")
		return errors.New("failed to retrieve describe from plumber")
	}

	pipelineRun := &entity.PipelineRun{}
	if err = pipelineRun.Load(describeResponse.Pipeline); err != nil {
		return nil
	}

	if !isValidRun(pipelineRun) {
		return nil
	}

	if err = entity.SavePipelineRun(pipelineRun); err != nil {
		log.Printf("failed to persist pipeline run: %v", err)
		return
	}

	if err = d.persistProjectRun(*pipelineRun); err != nil {
		log.Printf("failed to persist project run: %v", err)
		return
	}

	if err = d.persistMttr(*pipelineRun); err != nil {
		log.Printf("failed to persist mttr run: %v", err)
		return
	}

	return
}

func (d *PipelineDone) persistProjectRun(pipelineRun entity.PipelineRun) error {
	db := database.Conn()

	mttr := NewProjectRun(db, d.ProjectHubClient, pipelineRun.ProjectId, pipelineRun.PipelineFileName, pipelineRun.BranchName)

	return mttr.CheckWithPipeline(pipelineRun)
}

func (d *PipelineDone) persistMttr(pipelineRun entity.PipelineRun) error {
	db := database.Conn()

	mttr := NewMttr(db, d.ProjectHubClient, pipelineRun.ProjectId, pipelineRun.PipelineFileName, pipelineRun.BranchName)

	return mttr.CheckWithPipeline(pipelineRun)
}

func isValidRun(run *entity.PipelineRun) bool {
	return resultValid(run) && datesValid(run)
}

func resultValid(run *entity.PipelineRun) bool {
	if run.Reason == "MALFORMED" {
		return false
	}
	if run.Result == "CANCELED" {
		return false
	}
	return true
}

func datesValid(run *entity.PipelineRun) bool {
	return !isBeginningOfEpoch(run.DoneAt) && !isBeginningOfEpoch(run.RunningAt)
}

func isBeginningOfEpoch(date time.Time) bool {
	return date.Unix() == 0
}
