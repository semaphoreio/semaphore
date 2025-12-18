package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"strconv"
	"time"

	"github.com/renderedtext/go-watchman"
	privateserver "github.com/semaphoreio/semaphore/artifacthub/pkg/server/private"
	publicserver "github.com/semaphoreio/semaphore/artifacthub/pkg/server/public"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/util/log"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/workers/bucketcleaner"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/workers/jobdeletion"
	"go.uber.org/zap"
)

var (
	grpcPrivatePort = flag.Int("grpc_private_port", 50051, "The internal GRPC server port")
	grpcPublicPort  = flag.Int("grpc_public_port", 50052, "The public GRPC server port")

	metricPrefix                              = fmt.Sprintf("%s.%s", "artifacthub", os.Getenv("METRICS_NAMESPACE"))
	amqpURL                                   = os.Getenv("AMQP_URL")
	bucketcleanerSchedulerNaptime             = os.Getenv("BUCKETCLEANER_SCHEDULER_NAPTIME")
	bucketcleanerSchedulerBatchSize           = os.Getenv("BUCKETCLEANER_SCHEDULER_BATCHSIZE")
	bucketcleanerWorkerNumberOfObjectsInOneGo = os.Getenv("BUCKETCLEANER_WORKER_NUMBER_OF_PAGES_TO_PROCESS_IN_ONE_GO")
)

func configureWatchman() {
	onPremEnv, exists := os.LookupEnv("ON_PREM")
	if !exists {
		onPremEnv = "false"
	}
	onPrem := onPremEnv == "true"

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
		metricPrefix = namespace
	}

	log.Info("Connecting to StatsD")
	err := watchman.ConfigureWithOptions(watchman.Options{
		Host:                  h,
		Port:                  p,
		ExternalOnly:          onPrem,
		MetricPrefix:          metricPrefix,
		ConnectionAttempts:    15,
		ConnectionAttemptWait: 2 * time.Second,
	})
	if err != nil {
		log.Error("Error while connecting to statsd, err: %+v", zap.Error(err))
	}
}

func publicAPI(client storage.Client, secret string) {
	s := publicserver.NewServer(*grpcPublicPort, client, secret)
	log.Info("Starting public API...")
	s.Serve()
	log.Info("...public API stopped")
}

func internalAPI(client storage.Client, secret string) {
	s := privateserver.NewServer(*grpcPrivatePort, client, secret)
	log.Info("Starting internal API...")
	s.Serve()
	log.Info("...internal API stopped")
}

func bucketcleanerScheduler() {
	batchSize, err := strconv.ParseInt(bucketcleanerSchedulerBatchSize, 10, 64)
	if err != nil {
		log.Error("Failed to parse BUCKETCLEANER_SCHEDULER_BATCHSIZE")
		panic(err)
	}

	naptimeInSecs, err := strconv.ParseInt(bucketcleanerSchedulerNaptime, 10, 64)
	if err != nil {
		log.Error("Failed to parse BUCKETCLEANER_SCHEDULER_NAPTIME")
		panic(err)
	}

	naptime := time.Duration(naptimeInSecs) * time.Second

	log.Info("Starting bucketcleaner scheduler...")
	scheduler, err := bucketcleaner.NewScheduler(amqpURL, naptime, int(batchSize))
	if err != nil {
		panic(err)
	}

	scheduler.Start()
}

func bucketcleanerWorker(client storage.Client) {
	pages, err := strconv.ParseInt(bucketcleanerWorkerNumberOfObjectsInOneGo, 10, 32)
	if err != nil {
		log.Error("Failed to parse BUCKETCLEANER_WORKER_NUMBER_OF_PAGES_TO_PROCESS_IN_ONE_GO")
		panic(err)
	}

	worker, err := bucketcleaner.NewWorker(amqpURL, client)
	if err != nil {
		panic(err)
	}

	worker.NumberOfPagesToProcessInOneGo = int(pages)

	worker.Start()
}

func jobDeletionWorker(storageClient storage.Client) {
	log.Info("Starting job deletion worker...")
	worker, err := jobdeletion.NewWorker(amqpURL, storageClient)
	if err != nil {
		panic(err)
	}

	worker.Start()
}

func main() {
	flag.Parse()

	// listening Ctrl+C for being able to erease
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for range c {
			// sig is a ^C, handle it
			log.Info("quitting...")
			os.Exit(0)
		}
	}()

	configureWatchman()

	storageClient, err := storage.New()
	if err != nil {
		log.Error("Failed to connect to storage", zap.Error(err))
		panic(err)
	}

	if os.Getenv("START_PUBLIC_API") == "yes" {
		secret := requireEnvVar("JWT_HMAC_SECRET")
		go publicAPI(storageClient, secret)
	}

	if os.Getenv("START_INTERNAL_API") == "yes" {
		secret := requireEnvVar("JWT_HMAC_SECRET")
		go internalAPI(storageClient, secret)
	}

	if os.Getenv("START_BUCKETCLEANER_SCHEDULER") == "yes" {
		go bucketcleanerScheduler()
	}

	if os.Getenv("START_BUCKETCLEANER_WORKER") == "yes" {
		go bucketcleanerWorker(storageClient)
	}

	if os.Getenv("START_JOBDELETION_WORKER") == "yes" {
		go jobDeletionWorker(storageClient)
	}

	select {}
}

func requireEnvVar(varName string) string {
	varValue := os.Getenv(varName)
	if varValue == "" {
		fmt.Printf("%s can't be empty\n", varName)
		os.Exit(1)
	}

	return varValue
}
