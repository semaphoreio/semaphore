package bucketcleaner

import (
	"log"
	"os"
	"time"

	tackle "github.com/renderedtext/go-tackle"
	watchman "github.com/renderedtext/go-watchman"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/db"
	"github.com/semaphoreio/semaphore/artifacthub/pkg/models"
	"gorm.io/gorm"
)

type Scheduler struct {
	Naptime   time.Duration
	BatchSize int

	Running     bool
	Cycles      int
	amqpOptions *tackle.Options

	stopChannel chan bool
	ticker      *time.Ticker
}

func NewScheduler(amqpURL string, naptime time.Duration, batchSize int) (*Scheduler, error) {
	options := &tackle.Options{
		URL:            amqpURL,
		ConnectionName: schedulerConnName(),
		RemoteExchange: BucketCleanerExchange,
		Service:        BucketCleanerServiceName,
		RoutingKey:     BucketCleanerRoutingKey,
	}

	return &Scheduler{
		Naptime:     naptime,
		BatchSize:   batchSize,
		amqpOptions: options,
	}, nil
}

func schedulerConnName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "artifacthub.bucketcleaner.scheduler"
	}
	return hostname
}

func (s *Scheduler) Start() {
	s.stopChannel = make(chan bool)
	s.ticker = time.NewTicker(s.Naptime)
	s.Running = true

	go func() {
		s.workloop()

		s.Running = false
		s.Cycles = 0
		s.ticker.Stop()
		close(s.stopChannel)
	}()
}

func (s *Scheduler) Stop() {
	s.stopChannel <- true
}

func (s *Scheduler) workloop() {
	for {
		select {
		case <-s.stopChannel:
			return

		case <-s.ticker.C:
			s.Cycles++

			err := s.scheduleWork()
			if err != nil {
				_ = watchman.Increment("bucketcleaner.scheduler.failures")

				log.Printf("BucketCleaner: err while scheduling cleaning work %s", err.Error())
			}

			SubmitMetrics()
		}
	}
}

func (s *Scheduler) scheduleWork() error {
	defer watchman.Benchmark(time.Now(), "bucketcleaner.scheduler.tick.duration")

	log.Printf("BucketCleaner Scheduler: Scheduling work, batch size = %d", s.BatchSize)

	ids, err := s.loadBatch(db.Conn())
	if err != nil {
		return err
	}

	if len(ids) == 0 {
		return nil
	}

	_ = watchman.Submit("bucketcleaner.scheduler.batch.size", len(ids))

	published := s.publishBatch(ids)

	// Only what reached the broker is marked. Marking the whole batch put an artifact
	// whose publish failed out of reach for a day, with nothing left to retry it, and
	// for a purge that is a day of storage nobody asked to keep.
	if len(published) < len(ids) {
		_ = watchman.IncrementBy("bucketcleaner.scheduler.publish_failures", len(ids)-len(published))
	}

	if len(published) == 0 {
		return nil
	}

	return s.markBatchAsScheduled(db.Conn(), published)
}

func (s *Scheduler) loadBatch(tx *gorm.DB) ([]string, error) {
	policies := []models.RetentionPolicy{}
	result := []string{}

	query := tx.
		Table("retention_policies").
		Select("artifact_id").
		Set("gorm:query_option", "FOR UPDATE").
		Where("scheduled_for_cleaning_at IS NULL or scheduled_for_cleaning_at < now() - interval '1 day'").
		Where("last_cleaned_at IS NULL or last_cleaned_at < now() - interval '1 day'").
		Limit(s.BatchSize)

	err := query.Find(&policies).Error
	if err != nil {
		return result, err
	}

	for _, p := range policies {
		result = append(result, p.ArtifactID.String())
	}

	return result, nil
}

// publishBatch returns the ids whose clean request reached the broker. The rest
// stay due and are picked up on a later tick.
func (s *Scheduler) publishBatch(ids []string) []string {
	published := make([]string, 0, len(ids))

	for _, id := range ids {
		log.Printf("BucketCleaner Scheduler: Scheduling %s for cleaning", id)

		request, err := NewCleanRequest(id)
		if err != nil {
			log.Printf("Failed to schedule cleaning for %s, err: '%s'", id, err.Error())
			continue
		}

		body, err := request.ToJSON()
		if err != nil {
			log.Printf("Failed to schedule cleaning for %s, err: '%s'", id, err.Error())
			continue
		}

		err = tackle.PublishMessage(&tackle.PublishParams{
			Body:       body,
			AmqpURL:    s.amqpOptions.URL,
			RoutingKey: s.amqpOptions.RoutingKey,
			Exchange:   s.amqpOptions.RemoteExchange,
		})

		if err != nil {
			log.Printf("Failed to schedule cleaning for %s, err: '%s'", id, err.Error())
			continue
		}

		published = append(published, id)
	}

	return published
}

func (s *Scheduler) markBatchAsScheduled(tx *gorm.DB, ids []string) error {
	return tx.Table("retention_policies").
		Where("artifact_id IN (?)", ids).
		Update("scheduled_for_cleaning_at", gorm.Expr("now()")).
		Error
}
