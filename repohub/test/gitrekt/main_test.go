package gitrekt_test

import (
	"os"
	"testing"

	support "github.com/semaphoreio/semaphore/repohub/test/support"
)

func TestMain(m *testing.M) {
	support.SetupTestLogs()

	os.Exit(m.Run())
}
