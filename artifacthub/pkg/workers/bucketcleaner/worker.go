package bucketcleaner

import (
	"errors"
	"fmt"
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/storage"
	"gorm.io/gorm"
)

type Worker struct {
	amqpOptions                   *tackle.Options
	consumer                      *tackle.Consumer
	client                        storage.Client
	NumberOfPagesToProcessInOneGo int
}

const BucketCleanerExchange = "artifacthub.bucketcleaner"
const BucketCleanerServiceName = "artifacthub.bucketcleaner.worker"
const BucketCleanerRoutingKey = "clean"
const BucketCleanerDefaultNumberOfPagesInOneGo = 100

var ErrBucketAlreadyCleanedToday = fmt.Errorf("bucket already cleaned today")

func NewWorker(amqpURL string, client storage.Client) (*Worker, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: workerConnName(),
		RemoteExchange: BucketCleanerExchange,
		Service:        BucketCleanerServiceName,
		RoutingKey:     BucketCleanerRoutingKey,
	}

	consumer := tackle.NewConsumer()

	return &Worker{
		consumer:                      consumer,
		amqpOptions:                   options,
		client:                        client,
		NumberOfPagesToProcessInOneGo: BucketCleanerDefaultNumberOfPagesInOneGo,
	}, nil
}

func workerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "artifacthub.bucketcleaner.worker"
	}
	return hostname
}

func (w *Worker) Start() {
	go w.consumer.Start(w.amqpOptions, w.handleMessage)
}

func (w *Worker) Stop() {
	w.consumer.Stop()
}

func (w *Worker) state() string {
	return w.consumer.State
}

func (w *Worker) handleMessage(delivery tackle.Delivery) error {
	request, err := ParseCleanRequest(delivery.Body())
	if err != nil {
		log.Printf("BucketCleaner: failed to process message %s err %+v", delivery.Body(), err)
		return err
	}

	err = w.CleanBucket(request)
	if err != nil {
		_ = watchman.Increment("bucketcleaner.worker.failure")
		_ = watchman.External().IncrementWithTags("Artifacts.cleaner_run", []string{"failure"})

		if errors.Is(err, gorm.ErrRecordNotFound) {
			_ = watchman.Increment("bucketcleaner.worker.bucket_not_found")

			log.Printf("BucketCleaner: Artifact bucket no longer exists in the db id: %s", request.ArtifactBucketID.String())
			return nil
		}

		if errors.Is(err, ErrBucketAlreadyCleanedToday) {
			_ = watchman.Increment("bucketcleaner.worker.already_cleaned")

			log.Printf("BucketCleaner: Bucket was already cleaned today: %s", request.ArtifactBucketID.String())
			return nil
		}

		log.Printf("BucketCleaner: failed to clean bucket err=%v bucket=%s", err, request.ArtifactBucketID.String())
		return err
	}

	_ = watchman.External().IncrementWithTags("Artifacts.cleaner_run", []string{"success"})

	return nil
}

func (w *Worker) CleanBucket(cleanRequest *CleanRequest) error {
	defer watchman.BenchmarkWithTags(time.Now(), "bucketcleaner.worker.clean_duration", []string{cleanRequest.ArtifactBucketID.String()})

	var nextPageToken string

	err := w.withLock(cleanRequest.ArtifactBucketID.String(), func(tx *gorm.DB) error {
		cleaner := NewBatchCleaner(w.client, cleanRequest, w.NumberOfPagesToProcessInOneGo)
		token, err := cleaner.Run(tx)

		log.Printf("BucketCleaner: Cleaning bucket %s - visited=%d deleted=%d pagination-finished=%t destroyed=%t",
			cleanRequest.ArtifactBucketID,
			cleaner.visitedObjectCount,
			cleaner.deletedObjectCount,
			cleaner.paginationEnded,
			cleaner.artifactDeleted,
		)

		nextPageToken = token
		return err
	})

	if err != nil {
		return err
	}

	// If we didn't visit all files in the bucket,
	// we need to schedule a new cleaning operation again.
	// We should send the new RabbitMQ message for more work outside the transaction that locks it.
	if nextPageToken != "" {
		return w.scheduleMoreWorkAsync(cleanRequest, nextPageToken)
	}

	return nil
}

func (w *Worker) withLock(artifactID string, f func(tx *gorm.DB) error) error {
	return db.Conn().Transaction(func(tx *gorm.DB) error {
		lock := false

		err := tx.Raw("SELECT pg_try_advisory_xact_lock(hashtext(?))", artifactID).Row().Scan(&lock)
		if err != nil {
			log.Printf("Error while trying to acquire lock for %s: %v", artifactID, err)
			return err
		}

		if lock {
			// lock acquired, process
			return f(tx)
		}

		return nil
	})
}

func (w *Worker) scheduleMoreWorkAsync(cleanRequest *CleanRequest, token string) error {
	cleanRequest.PaginationToken = token
	body, err := cleanRequest.ToJSON()
	if err != nil {
		return err
	}

	err = tackle.PublishMessage(&tackle.PublishParams{
		Body:       body,
		AmqpURL:    w.amqpOptions.URL,
		RoutingKey: BucketCleanerRoutingKey,
		Exchange:   BucketCleanerExchange,
	})

	if err != nil {
		log.Printf("Error while scheduling next cycle id=%s err=%+v", cleanRequest.ArtifactBucketID.String(), err)
	}

	return err
}
