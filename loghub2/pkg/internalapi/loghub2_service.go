package internalapi

import (
	"context"
	"log"
	"time"

	"github.com/renderedtext/go-watchman"
	auth "github.com/semaphoreio/semaphore/loghub2/pkg/auth"
	pb "github.com/semaphoreio/semaphore/loghub2/pkg/protos/loghub2"
)

type Loghub2Service struct {
	privateKey string
}

func NewLoghub2Service(privateKey string) *Loghub2Service {
	return &Loghub2Service{privateKey: privateKey}
}

func (s *Loghub2Service) GenerateToken(ctx context.Context, request *pb.GenerateTokenRequest) (*pb.GenerateTokenResponse, error) {
	defer watchman.Benchmark(time.Now(), "token.generate")

	duration := time.Duration(request.Duration) * time.Second
	if duration == 0 {
		duration = time.Hour
	}

	log.Printf("GenerateToken, duration %v: %v", request, duration)
	token, err := auth.GenerateToken(s.privateKey, request.GetJobId(), request.GetType().String(), duration)
	if err != nil {
		log.Printf("Error generating token for %s: %v", request.GetJobId(), err)
		return nil, err
	}

	response := &pb.GenerateTokenResponse{
		Token: token,
		Type:  request.GetType(),
	}

	return response, nil
}
