// Package entity holds all database related entities.
package entity

import protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"

type AfterPipeline struct {
	pb *protos.AfterPipelineEvent
}

func NewAfterPipeline(pb *protos.AfterPipelineEvent) *AfterPipeline {
	return &AfterPipeline{pb: pb}
}

func (a *AfterPipeline) HasEmptyID() bool {
	return len(a.pb.PipelineId) == 0
}

func (a *AfterPipeline) PipelineID() string {
	return a.pb.PipelineId
}

func (a *AfterPipeline) IsDone() bool {
	return a.pb.State == protos.AfterPipeline_DONE
}
