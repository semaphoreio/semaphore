package main

import (
	"fmt"
	"log"
	"net"

	"golang.org/x/net/context"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"

	pbjobs "github.com/semaphoreio/semaphore/public-api-gateway/api/jobs.v1alpha"
	pb "github.com/semaphoreio/semaphore/public-api-gateway/api/secrets.v1beta"
)

type server struct{}

func (s *server) ListSecrets(ctx context.Context, req *pb.ListSecretsRequest) (*pb.ListSecretsResponse, error) {
	return &pb.ListSecretsResponse{}, nil
}

func (s *server) GetSecret(ctx context.Context, req *pb.GetSecretRequest) (*pb.Secret, error) {
	return &pb.Secret{}, nil
}

func (s *server) UpdateSecret(ctx context.Context, req *pb.UpdateSecretRequest) (*pb.Secret, error) {
	return &pb.Secret{}, nil
}

func (s *server) CreateSecret(ctx context.Context, req *pb.Secret) (*pb.Secret, error) {
	log.Printf("Incomming Create Request")

	if req == nil {
		log.Printf("req is nil")
	} else {
		log.Printf("%+v", req)
	}

	log.Printf("---------------")
	log.Printf("%+v", ctx)
	log.Printf("---------------")
	log.Printf("%+v", req)
	log.Printf("---------------")
	log.Printf("%+v", req)

	log.Printf("---------------")
	headers, _ := metadata.FromIncomingContext(ctx)
	authorization := headers["authorization"]
	randomHeader := headers["x-some-other-header"]

	log.Printf("%s", authorization)
	log.Printf("%s", randomHeader)

	return &pb.Secret{}, nil
}

func (s *server) DeleteSecret(ctx context.Context, req *pb.DeleteSecretRequest) (*pb.Empty, error) {
	return &pb.Empty{}, nil
}

func main() {
	port := 50051

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	log.Printf("Listening on localhost:%d", port)

	grpcServer := grpc.NewServer()
	pb.RegisterSecretsApiServer(grpcServer, &server{})
	pbjobs.RegisterJobsApiServer(grpcServer, &jobsServer{})
	err = grpcServer.Serve(lis)
	if err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
