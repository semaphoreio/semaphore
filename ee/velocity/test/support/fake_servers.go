package support

import (
	"crypto/rand"
	"fmt"
	"log"
	"math/big"
	"net"
	"time"

	"github.com/google/uuid"

	"github.com/semaphoreio/semaphore/velocity/pkg/protos/feature"
	plumber "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	projectHub "github.com/semaphoreio/semaphore/velocity/pkg/protos/projecthub"
	"google.golang.org/grpc"

	"github.com/semaphoreio/semaphore/velocity/pkg/config"
)

var FakeProjectId = "00000000-0000-0000-0000-000000000000" // Will be initialized with a real UUID in init()

func init() {
	FakeProjectId = uuid.New().String()
}

func generateRandomPort(max int64) int {
	random, err := rand.Int(rand.Reader, big.NewInt(max))
	if err != nil {
		return 30000
	}
	return 30000 + int(random.Int64())
}

func StartFakeServers() {

	config.FakeServerPortInTests = generateRandomPort(1000)

	endpoint := fmt.Sprintf("0.0.0.0:%d", config.FakeServerPortInTests)
	lis, err := net.Listen("tcp", endpoint)

	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer()

	plumber.RegisterPipelineServiceServer(grpcServer, &FakePipelineServiceServer{
		ProjectID:         FakeProjectId,
		Branches:          []string{"master", "deploy"},
		PipelineFileNames: []string{"semaphore.yml", "deploy.yml"},
	})

	projectHub.RegisterProjectServiceServer(grpcServer, &FakeProjectHubServiceServer{})
	feature.RegisterFeatureServiceServer(grpcServer, &FakeFeatureServiceServer{})

	log.Printf("Starting Fake GRPC servers on %s.", endpoint)

	go func() {
		err := grpcServer.Serve(lis)
		if err != nil {
			log.Fatalf("failed to start grpc server with: %v", err)
		}
	}()

	time.Sleep(3 * time.Second) // Give some time for the server to start
}
