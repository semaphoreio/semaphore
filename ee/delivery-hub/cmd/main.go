package main

import (
	"os"
	"time"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	grpc "github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/public"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/workers"
	log "github.com/sirupsen/logrus"
)

func startWorkers() {
	log.Println("Starting Workers")

	if os.Getenv("START_PENDING_EVENTS_WORKER") == "true" {
		log.Println("Starting Pending Events Worker")
		w := workers.PendingEventsWorker{}
		go w.Start()
	}

	if os.Getenv("START_PENDING_STAGE_EVENTS_WORKER") == "true" {
		log.Println("Starting Pending Stage Events Worker")
		w := workers.PendingStageEventsWorker{}
		go w.Start()
	}

	if os.Getenv("START_PENDING_EXECUTIONS_WORKER") == "true" {
		log.Println("Starting Pending Stage Events Worker")

		repoProxyURL, err := config.RepoProxyURL()
		if err != nil {
			panic(err)
		}

		w := workers.PendingExecutionsWorker{
			RepoProxyURL: repoProxyURL,
		}

		go w.Start()
	}
}

func startInternalAPI(encryptor encryptor.Encryptor) {
	log.Println("Starting Internal API")
	grpc.RunServer(encryptor, 50051)
}

func startPublicAPI(encryptor encryptor.Encryptor) {
	log.Println("Starting Public API")

	server, err := public.NewServer(encryptor)
	if err != nil {
		log.Panicf("Error creating public API server: %v", err)
	}

	err = server.Serve("0.0.0.0", 8000)
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	log.SetFormatter(&log.TextFormatter{TimestampFormat: time.StampMilli})

	encryptorURL := os.Getenv("ENCRYPTOR_URL")
	if encryptorURL == "" {
		panic("ENCRYPTOR_URL can't be empty")
	}

	encryptor := encryptor.NewGrpcEncryptor(encryptorURL)

	if os.Getenv("START_PUBLIC_API") == "yes" {
		go startPublicAPI(encryptor)
	}

	if os.Getenv("START_INTERNAL_API") == "yes" {
		go startInternalAPI(encryptor)
	}

	startWorkers()

	log.Println("Delivery Hub is UP.")

	select {}
}
