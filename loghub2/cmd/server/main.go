package main

import (
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/loghub2/pkg/amqp"
	"github.com/semaphoreio/semaphore/loghub2/pkg/internalapi"
	"github.com/semaphoreio/semaphore/loghub2/pkg/publicapi"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"github.com/semaphoreio/semaphore/loghub2/pkg/utils"
	"github.com/semaphoreio/semaphore/loghub2/pkg/workers/jobdeletion"
)

const (
	ConnectionRetries   = 20
	ConnectionRetryWait = 2
	MetricsService      = "loghub2"
)

func startPublicAPI(redisStorage *storage.RedisStorage, cloudStorage storage.Storage) {
	log.Println("Starting Public API")

	privateKey := utils.AssertEnvVar("LOGHUB2_PRIVATE_KEY")
	host := utils.AssertEnvVar("PUBLIC_API_HOST")
	apiPort := utils.AssertEnvVar("PUBLIC_API_PORT")
	port, err := strconv.Atoi(apiPort)
	if err != nil {
		panic("Public API port can't be empty")
	}

	server, err := publicapi.NewServer(redisStorage, cloudStorage, privateKey)
	if err != nil {
		log.Panicf("Error creating Public API server: %v\n", err)
	}

	err = server.Serve(host, port)
	if err != nil {
		log.Panicf("Error starting Public API server: %v\n", err)
	}
}

func startInternalAPI() {
	log.Println("Starting Internal API")
	privateKey := utils.AssertEnvVar("LOGHUB2_PRIVATE_KEY")
	internalapi.RunServer(50051, privateKey)
}

func configureWatchman() {
	onPremEnv, exists := os.LookupEnv("ON_PREM")
	if !exists {
		onPremEnv = "false"
	}
	onPrem := onPremEnv == "true"
	var metricsChannel watchman.MetricsChannel
	var metricsBackend watchman.BackendType

	if onPrem {
		metricsChannel = watchman.ExternalOnly
		metricsBackend = watchman.BackendCloudwatch
	}

	h, filterExternal := os.LookupEnv("METRICS_HOST")
	if !filterExternal {
		h = "0.0.0.0"
	}

	p, exists := os.LookupEnv("METRICS_PORT")
	if !exists {
		p = "8125"
	}

	metricNamespace := MetricsService
	namespace, exists := os.LookupEnv("METRICS_NAMESPACE")
	if exists {
		metricNamespace = fmt.Sprintf("%s.%s", MetricsService, namespace)
	}

	prefix, exists := os.LookupEnv("METRICS_PREFIX")
	if exists {
		metricNamespace = prefix
	}

	err := watchman.ConfigureWithOptions(watchman.Options{
		Host:                  h,
		Port:                  p,
		MetricsChannel:        metricsChannel,
		BackendType:           metricsBackend,
		MetricPrefix:          metricNamespace,
		ConnectionAttempts:    30,
		ConnectionAttemptWait: 2 * time.Second,
	})
	if err != nil {
		log.Printf("Failed to configure watchman: %v", err)
	}
}

func startRabbitMQConsumer(redisStorage *storage.RedisStorage, cloudStorage storage.Storage) {
	log.Println("Starting RabbitMQ Consumer")

	rabbitMqURL := utils.AssertEnvVar("RABBITMQ_URL")

	consumer := amqp.NewAmqpConsumer(redisStorage, cloudStorage)
	options := tackle.Options{
		URL:            rabbitMqURL,
		RemoteExchange: "server_farm.job_state_exchange",
		Service:        "loghub2.archivator",
		RoutingKey:     "job_teardown_finished",
		ConnectionName: utils.ClientConnectionName(),
	}

	err := utils.RetryWithConstantWait("RabbitMQ connection", ConnectionRetries, ConnectionRetryWait*time.Second, func() error {
		return consumer.Start(&options)
	})
	if err != nil {
		log.Fatalf("Error connecting to rabbitmq: %v", err)
	}
}

func jobDeletionWorker(cloudStorage storage.Storage) {
	log.Println("Starting job deletion worker...")

	rabbitMqURL := utils.AssertEnvVar("RABBITMQ_URL")

	worker, err := jobdeletion.NewWorker(rabbitMqURL, cloudStorage)
	if err != nil {
		panic(err)
	}

	worker.Start()
}

func createRedisStorage() *storage.RedisStorage {
	host := utils.AssertEnvVar("REDIS_HOST")
	port := utils.AssertEnvVar("REDIS_PORT")
	username := os.Getenv("REDIS_USERNAME")
	password := os.Getenv("REDIS_PASSWORD")
	redisStorage := storage.NewRedisStorage(storage.RedisConfig{
		Address:  host,
		Port:     port,
		Username: username,
		Password: password,
	})

	err := utils.RetryWithConstantWait("Redis connection", ConnectionRetries, ConnectionRetryWait*time.Second, func() error {
		return redisStorage.CheckConnection()
	})

	if err != nil {
		log.Fatalf("Error connecting to redis: %v", err)
	}

	return redisStorage
}

func shouldInitializeStorages() bool {
	return os.Getenv("START_PUBLIC_API") == "yes" || os.Getenv("START_ARCHIVATOR") == "yes" || os.Getenv("START_JOB_DELETION_WORKER") == "yes"
}

func main() {
	configureWatchman()

	if os.Getenv("START_INTERNAL_API") == "yes" {
		go startInternalAPI()
	}

	var cloudStorage storage.Storage
	var redisStorage *storage.RedisStorage
	var err error
	if shouldInitializeStorages() {
		redisStorage = createRedisStorage()

		cloudStorage, err = storage.InitStorage()

		if err != nil {
			log.Fatalf("Failed to initialize cloud storage: %v", err)
		}
	}

	if os.Getenv("START_PUBLIC_API") == "yes" {
		go startPublicAPI(redisStorage, cloudStorage)
	}

	if os.Getenv("START_ARCHIVATOR") == "yes" {
		go startRabbitMQConsumer(redisStorage, cloudStorage)
	}

	if os.Getenv("START_JOB_DELETION_WORKER") == "yes" {
		go jobDeletionWorker(cloudStorage)
	}

	log.Println("loghub2 is UP.")
	select {}
}
