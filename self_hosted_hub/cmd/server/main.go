package main

import (
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/amqp"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/config"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/feature"
	internalapi "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/internalapi"
	publicapi "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/publicapi"
	quotas "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/quotas"
	agentcleaner "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/agentcleaner"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/agentcounter"
	disconnected_cleaner "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/disconnectedcleaner"
	"github.com/semaphoreio/semaphore/self_hosted_hub/pkg/workers/metrics"
	log "github.com/sirupsen/logrus"
)

var metricService = "self_hosted_hub"

func startPublicAPI() {
	log.Println("Starting Public API")

	host := os.Getenv("PUBLIC_API_HOST")
	port, err := strconv.Atoi(os.Getenv("PUBLIC_API_PORT"))
	if err != nil {
		panic("Public API port can't be empty")
	}

	provider, err := configureFeatureProvider()
	if err != nil {
		panic(err)
	}

	quotaClient, err := quotas.NewQuotaClient(provider)
	if err != nil {
		log.Panicf("Error creating quota client: %v", err)
	}

	agentCounterInterval := time.Second
	agentCounter, err := agentcounter.NewAgentCounter(&agentCounterInterval)
	if err != nil {
		log.Fatalf("Error creating agent counter: %v", err)
	}

	publisher := createPublisher()

	server, err := publicapi.NewServer(quotaClient, agentCounter, publisher)
	if err != nil {
		log.Panicf("Error creating server: %v", err)
	}

	err = server.Serve(host, port)
	if err != nil {
		log.Fatal(err)
	}
}

func startInternalAPI() {
	provider, err := configureFeatureProvider()
	if err != nil {
		panic(err)
	}

	quotaClient, err := quotas.NewQuotaClient(provider)
	if err != nil {
		log.Panicf("Error creating quota client: %v", err)
	}

	log.Println("Starting Internal API")
	internalapi.RunServer(50051, quotaClient)
}

func startAgentCleaners() {
	publisher := createPublisher()
	go startAgentCleaner(publisher)
	go startDisconnectedAgentCleaner(publisher)
}

func startAgentCleaner(publisher *amqp.Publisher) {
	log.Println("Starting Agent Cleaner")
	agentcleaner.Start(publisher)
}

func startDisconnectedAgentCleaner(publisher *amqp.Publisher) {
	log.Println("Starting Disconnected Agent Cleaner")
	disconnected_cleaner.Start(publisher)
}

func startMetricsCollector() {
	log.Println("Starting metrics collector")
	collector := metrics.NewCollector()
	collector.Start()
}

func configureWatchman(metricNamespace string) {
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

	namespace, exists := os.LookupEnv("METRICS_PREFIX")
	if exists {
		metricNamespace = namespace
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
		log.Printf("(err) Failed to configure watchman")
	}
}

func configureFeatureProvider() (feature.Provider, error) {
	featureYamlPath := os.Getenv("FEATURE_YAML_PATH")
	if featureYamlPath == "" {
		return feature.NewFeatureHubProvider(config.FeatureAPIEndpoint())
	}

	return feature.NewYamlProvider(featureYamlPath)
}

func main() {
	log.SetFormatter(&log.JSONFormatter{TimestampFormat: time.StampMilli})
	log.SetOutput(os.Stdout)

	log.SetLevel(log.InfoLevel)
	if os.Getenv("LOG_LEVEL") != "" {
		level, err := log.ParseLevel(os.Getenv("LOG_LEVEL"))
		if err != nil {
			log.Fatalf("Invalid log level: %v", err)
		}
		log.SetLevel(level)
	}

	configureWatchman(fmt.Sprintf("%s.%s", metricService, os.Getenv("METRICS_NAMESPACE")))

	if os.Getenv("START_INTERNAL_API") == "yes" {
		go startInternalAPI()
	}

	if os.Getenv("START_PUBLIC_API") == "yes" {
		go startPublicAPI()
	}

	if os.Getenv("START_AGENT_CLEANER") == "yes" {
		startAgentCleaners()
	}

	if os.Getenv("START_METRICS_COLLECTOR") == "yes" {
		go startMetricsCollector()
	}

	log.Println("Self Hosted Hub is UP.")

	select {}
}

// Creates a publisher for AMQP
// Panics if RABBITMQ_URL is not set or if there is an error creating the publisher
func createPublisher() *amqp.Publisher {
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		panic("RABBITMQ_URL is required to run the service")
	}

	publisher, err := amqp.NewPublisher(rabbitURL)
	if err != nil {
		log.Fatalf("Error creating AMQP publisher: %v", err)
	}
	return publisher
}
