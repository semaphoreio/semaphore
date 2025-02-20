package service

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	farm "github.com/semaphoreio/semaphore/velocity/pkg/protos/server_farm.job"
	"google.golang.org/grpc"
)

type ServerFarmGrpcClient struct {
	conn *grpc.ClientConn
}

type ServerFarmClient interface {
	Describe(in *farm.DescribeRequest) (*farm.DescribeResponse, error)
}

func NewServerFarm(conn *grpc.ClientConn) ServerFarmClient {
	return &ServerFarmGrpcClient{
		conn: conn,
	}
}

func (s *ServerFarmGrpcClient) Describe(in *farm.DescribeRequest) (*farm.DescribeResponse, error) {
	client := farm.NewJobServiceClient(s.conn)

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	return client.Describe(tCtx, in)
}
