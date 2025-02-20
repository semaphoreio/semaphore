package grpcmock

import (
	"context"

	loghub2pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/loghub2"
)

type Loghub2Service struct {
}

func NewLoghub2Service() Loghub2Service {
	return Loghub2Service{}
}

func (z Loghub2Service) GenerateToken(context.Context, *loghub2pb.GenerateTokenRequest) (*loghub2pb.GenerateTokenResponse, error) {
	return &loghub2pb.GenerateTokenResponse{Token: "f87g478gf89g398gv48bv48h0909djaf9j"}, nil
}
