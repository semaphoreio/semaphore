package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"github.com/renderedtext/go-watchman"
	cleaner "github.com/semaphoreio/semaphore/repohub/pkg/cleaner"
	fetcher "github.com/semaphoreio/semaphore/repohub/pkg/fetcher"
	hub "github.com/semaphoreio/semaphore/repohub/pkg/hub"
	metrics "github.com/semaphoreio/semaphore/repohub/pkg/metrics"
)

var (
	metricPrefix = fmt.Sprintf("%s.%s", "repohub", os.Getenv("METRICS_NAMESPACE"))

	startInternalAPI = os.Getenv("START_INTERNAL_API")
	startRepoFetcher = os.Getenv("START_REPO_FETCHER")
	startCleaner     = os.Getenv("START_REPO_CLEANER")
	startMonitor     = os.Getenv("START_MONITOR")
)

func configureWatchman() {
	err := watchman.ConfigureWithOptions(watchman.Options{
		Host:                  "0.0.0.0",
		Port:                  "8125",
		MetricsChannel:        watchman.InternalOnly,
		BackendType:           watchman.BackendGraphite,
		MetricPrefix:          metricPrefix,
		ConnectionAttempts:    30,
		ConnectionAttemptWait: 2 * time.Second,
	})

	if err != nil {
		log.Printf("(err) Failed to configure watchman")
	}
}

func main() {
	log.SetFlags(log.Ldate | log.Lmicroseconds | log.Lshortfile)

	configureWatchman()

	db := hub.DbConnection()

	if startRepoFetcher == "yes" {
		log.Println("Starting Repository Fetcher")

		go func() {
			fetcher.NewFetcher(db).Run()
		}()
	}

	if startCleaner == "yes" {
		log.Println("Starting Repository Cleaner")

		go func() {
			cleaner.Run(db)
		}()
	}

	if startMonitor == "yes" {
		log.Println("Starting Monitor")

		go func() {
			metrics.Run(db)
		}()
	}

	if startInternalAPI == "yes" {
		log.Println("Starting Internal API")

		go func() {
			hub.RunServer(db, 50051)
		}()
	}

	log.Println("RepoHub Fully Working")

	// sleep forever
	select {}
}
