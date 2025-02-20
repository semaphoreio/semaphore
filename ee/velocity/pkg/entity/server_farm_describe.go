package entity

import (
	"github.com/google/uuid"
	farm "github.com/semaphoreio/semaphore/velocity/pkg/protos/server_farm.job"
)

type ServerFarmDescribe struct {
	pb *farm.DescribeResponse
}

func NewServerFarmDescribe(pb *farm.DescribeResponse) *ServerFarmDescribe {
	return &ServerFarmDescribe{pb: pb}
}

func (s *ServerFarmDescribe) IsValid() bool {
	return s.pb.Job != nil && len(s.pb.Job.ProjectId) > 0 && len(s.pb.Job.PplId) > 0
}

func (s *ServerFarmDescribe) ProjectID() string {
	return s.pb.Job.ProjectId
}

func (s *ServerFarmDescribe) PipelineID() uuid.UUID {
	// I want it to crash if it cannot parse because server farm will be sending wrong data.
	return uuid.MustParse(s.pb.Job.PplId)
}
