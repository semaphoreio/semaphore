package cleaner

import (
	"flag"
	"log"
	"os"
	"runtime/debug"
	"time"

	gorm "github.com/jinzhu/gorm"
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
)

//
// Worker for marking repositories that are not connected to any DB record.
//

func Run(db *gorm.DB) {
	for {
		time.Sleep(5 * 60 * time.Second)

		panicHandler(func() {
			Check(db)
		})
	}
}

func Check(db *gorm.DB) {
	repos, err := models.ListAllRepositories(db)
	if err != nil {
		log.Printf("error: %s", err.Error())
		return
	}

	files, err := os.ReadDir("/var/repos/")
	if err != nil {
		log.Fatal(err)
		return
	}

	for _, f := range files {
		found := false

		for _, r := range repos {
			if r.ID.String() == f.Name() {
				found = true
				break
			}
		}

		if !found {
			log.Printf("Orphan repo found /var/repos/%s. DB record no longer exists.\n", f.Name())
			// remove the repo
			err := os.RemoveAll("/var/repos/" + f.Name())
			if err != nil {
				log.Printf("Failed to remove orphan repo %s, err: %s", f.Name(), err.Error())
			}
		}
	}
}

func panicHandler(f func()) {
	defer func() {
		if p := recover(); p != nil {
			log.Println(p)
			log.Println(string(debug.Stack()))

			if flag.Lookup("test.v") != nil {
				panic(p)
			}
		}
	}()

	f()
}
