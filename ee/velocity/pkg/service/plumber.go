package service

import (
	"context"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	plumber "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	"google.golang.org/grpc"
)

type PlumberGrpcClient struct {
	conn *grpc.ClientConn
}

type PlumberClient interface {
	Describe(in *plumber.DescribeRequest) (*plumber.DescribeResponse, error)
}

func NewPlumberService(conn *grpc.ClientConn) *PlumberGrpcClient {
	return &PlumberGrpcClient{
		conn: conn,
	}
}

func (c *PlumberGrpcClient) Describe(in *plumber.DescribeRequest) (*plumber.DescribeResponse, error) {

	client := plumber.NewPipelineServiceClient(c.conn)

	tCtx, cancel := context.WithTimeout(context.Background(), config.GrpcCallTimeout()*time.Second)
	defer cancel()
	return client.Describe(tCtx, in)
}
