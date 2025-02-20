package cleaner_test

import (
	"testing"

	cleaner "github.com/semaphoreio/semaphore/repohub/pkg/cleaner"
	support "github.com/semaphoreio/semaphore/repohub/test/support"
)

func Test__Check(t *testing.T) {
	support.PurgeDB()

	support.CreateRepository().ToGitrektRepository()

	cleaner.Check(support.DB)
}
