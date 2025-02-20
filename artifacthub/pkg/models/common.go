package models

import (
	"flag"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
)

// Check checks that all tables are in place and available.
func Check() bool {
	return db.Conn().Migrator().HasTable(&Artifact{})
}

func PrepareDatabaseForTests() {
	if flag.Lookup("test.v") == nil {
		// we are not in a test environment
		panic("trying to truncate database in non-test environment")
	}

	err := db.Conn().Exec(`truncate table artifacts, retention_policies`).Error
	if err != nil {
		panic(err)
	}

	log.Info("All artifacts has been deleted")
}
