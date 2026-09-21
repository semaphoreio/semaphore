package hub_test

import (
	"log"
	"os"
	"testing"
	"time"

	hub "github.com/semaphoreio/semaphore/repohub/pkg/hub"
	support "github.com/semaphoreio/semaphore/repohub/test/support"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

var testConn *grpc.ClientConn = nil

func TestMain(m *testing.M) {
	support.ConnectDB()
	support.SetupTestLogs()
	server := support.StartFakeServers()

	go func() {
		hub.RunServer(support.DB, 4000)
	}()

	// Give some time for the server to start
	time.Sleep(5 * time.Second)

	conn, err := grpc.NewClient("0.0.0.0:4000", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("error opening connection to local GPRC server: %v", err)
	}
	defer conn.Close()

	testConn = conn

	exitCode := m.Run()
	server.Stop()
	os.Exit(exitCode)
}
