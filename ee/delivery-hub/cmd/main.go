package main

import (
	"os"
	"time"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/config"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	grpc "github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/jwt"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/public"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/workers"
	log "github.com/sirupsen/logrus"
)

func startWorkers(jwtSigner *jwt.Signer) {
	log.Println("Starting Workers")

	rabbitMQURL, err := config.RabbitMQURL()
	if err != nil {
		panic(err)
	}

	if os.Getenv("START_PENDING_EVENTS_WORKER") == "yes" {
		log.Println("Starting Pending Events Worker")
		w := workers.PendingEventsWorker{}
		go w.Start()
	}

	if os.Getenv("START_PENDING_STAGE_EVENTS_WORKER") == "yes" {
		log.Println("Starting Pending Stage Events Worker")
		w := workers.PendingStageEventsWorker{}
		go w.Start()
	}

	if os.Getenv("START_STAGE_EVENT_APPROVED_CONSUMER") == "yes" {
		log.Println("Starting Stage Event Approved Consumer")
		w := workers.NewStageEventApprovedConsumer(rabbitMQURL)
		go w.Start()
	}

	if os.Getenv("START_PIPELINE_DONE_CONSUMER") == "yes" {
		log.Println("Starting Pipeline Done Consumer")

		pipelineAPIURL, err := config.PipelineAPIURL()
		if err != nil {
			panic(err)
		}

		w := workers.NewPipelineDoneConsumer(rabbitMQURL, pipelineAPIURL)
		go w.Start()
	}

	if os.Getenv("START_PENDING_EXECUTIONS_WORKER") == "yes" {
		log.Println("Starting Pending Stage Events Worker")

		repoProxyURL, err := config.RepoProxyURL()
		if err != nil {
			panic(err)
		}

		schedulerURL, err := config.SchedulerAPIURL()
		if err != nil {
			panic(err)
		}

		w := workers.PendingExecutionsWorker{
			RepoProxyURL: repoProxyURL,
			SchedulerURL: schedulerURL,
			JwtSigner:    jwtSigner,
		}

		go w.Start()
	}
}

func startInternalAPI(encryptor encryptor.Encryptor) {
	log.Println("Starting Internal API")
	grpc.RunServer(encryptor, 50051)
}

func startPublicAPI(encryptor encryptor.Encryptor, jwtSigner *jwt.Signer) {
	log.Println("Starting Public API")

	basePath := os.Getenv("PUBLIC_API_BASE_PATH")
	if basePath == "" {
		panic("PUBLIC_API_BASE_PATH must be set")
	}

	server, err := public.NewServer(encryptor, jwtSigner, basePath)
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

	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		panic("JWT_SECRET must be set")
	}

	jwtSigner := jwt.NewSigner(jwtSecret)

	if os.Getenv("START_PUBLIC_API") == "yes" {
		go startPublicAPI(encryptor, jwtSigner)
	}

	if os.Getenv("START_INTERNAL_API") == "yes" {
		go startInternalAPI(encryptor)
	}

	startWorkers(jwtSigner)

	log.Println("Delivery Hub is UP.")

	select {}
}
