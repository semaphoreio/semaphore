package fetcher_test

import (
	"os"
	"testing"

	support "github.com/semaphoreio/semaphore/repohub/test/support"
)

func TestMain(m *testing.M) {
	support.ConnectDB()
	support.SetupTestLogs()
	server := support.StartFakeServers()
	exitCode := m.Run()
	server.Stop()
	os.Exit(exitCode)
}
