package amqp

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	protos "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.mq.job_state_exchange"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/known/timestamppb"
)

const (
	RedisChunkSize = 200
)

type AmqpConsumer struct {
	redisStorage *storage.RedisStorage
	cloudStorage storage.Storage
	consumer     *tackle.Consumer
}

func NewAmqpConsumer(redisStorage *storage.RedisStorage, cloudStorage storage.Storage) *AmqpConsumer {
	return &AmqpConsumer{
		redisStorage,
		cloudStorage,
		tackle.NewConsumer(),
	}
}

func (c *AmqpConsumer) Start(options *tackle.Options) error {
	options.OnDeadFunc = c.ExecuteWhenMessageIsDead
	return c.consumer.Start(options, c.processMessage)
}

func (c *AmqpConsumer) Stop() {
	c.consumer.Stop()
}

func (c *AmqpConsumer) State() string {
	return c.consumer.State
}

func (c *AmqpConsumer) processMessage(delivery tackle.Delivery) error {
	// Processing a message should not take longer than 1 minute.
	ctx, cancelFunc := context.WithTimeout(context.Background(), time.Minute)
	defer cancelFunc()

	jobFinished := &protos.JobFinished{}
	if err := proto.Unmarshal(delivery.Body(), jobFinished); err != nil {
		return fmt.Errorf("failed to parse job finished message: %v", err)
	}

	jobId := jobFinished.GetJobId()
	if !jobFinished.SelfHosted {
		log.Printf("Ignoring job finished message for hosted job %s", jobId)
		return nil
	}

	log.Printf("Received delivery for %s", jobId)
	fileName, logsWritten, err := c.redisStorage.GetLogsAsFile(ctx, jobId, RedisChunkSize)
	if err != nil {
		return fmt.Errorf("error getting logs for %s from Redis: %v", jobId, err)
	}

	if logsWritten == 0 {
		log.Printf("Job %s has no logs in Redis - not saving anything in cloud storage", jobId)
		return nil
	}

	compressedFileName, err := compressLogs(ctx, fileName)
	if err != nil {
		return fmt.Errorf("error compressing logs for %s: %v", jobId, err)
	}

	err = c.saveInCloudStorage(ctx, compressedFileName, jobId)
	if err != nil {
		_ = watchman.External().IncrementWithTags("export", []string{"result", "failure"})
		return fmt.Errorf("error saving logs for %s in cloud storage: %v", jobId, err)
	}

	_ = watchman.External().IncrementWithTags("export", []string{"result", "success"})
	if err := os.Remove(compressedFileName); err != nil {
		log.Printf("Error removing %s: %v", compressedFileName, err)
	}

	_, err = c.redisStorage.DeleteLogs(ctx, jobId)
	if err != nil {
		return fmt.Errorf("error deleting logs for %s from Redis: %v", jobId, err)
	}

	publishProcessingDelayMetric(jobFinished.GetTimestamp())
	return nil
}

func publishProcessingDelayMetric(finishedAt *timestamppb.Timestamp) {
	now := time.Now().UnixNano()
	finishedAtEpoch := finishedAt.AsTime().UnixNano()
	processingTimeInMilliseconds := (now - int64(finishedAtEpoch)) / 1000 / 1000
	err := watchman.Submit("logs.processing", int(processingTimeInMilliseconds))
	if err != nil {
		log.Printf("Error submitting metrics: %v", err)
	}
}

func compressLogs(ctx context.Context, fileName string) (string, error) {
	// #nosec
	fileInfo, err := os.Stat(fileName)
	if err != nil {
		return "", err
	}

	err = watchman.Submit("log.uncompressed", int(fileInfo.Size()))
	if err != nil {
		log.Printf("Error submitting metrics: %v", err)
	}

	log.Printf("Compressing %s before uploading", fileName)
	err = storage.Gzip(ctx, fileName)
	if err != nil {
		return "", err
	}

	gzippedFileName := fmt.Sprintf("%s.gz", fileName)

	// #nosec
	gzippedFileInfo, err := os.Stat(gzippedFileName)
	if err != nil {
		return "", err
	}

	err = watchman.Submit("log.compressed", int(gzippedFileInfo.Size()))
	if err != nil {
		log.Printf("Error submitting metrics: %v", err)
	}

	return gzippedFileName, nil
}

func (c *AmqpConsumer) saveInCloudStorage(ctx context.Context, fileName, jobId string) error {
	err := c.cloudStorage.SaveFile(ctx, fileName, jobId)
	if err != nil {
		return err
	}

	log.Printf("Saved logs for %s in cloud storage", jobId)
	return nil
}

func (c *AmqpConsumer) ExecuteWhenMessageIsDead(delivery tackle.Delivery) {
	jobFinished := &protos.JobFinished{}
	if err := proto.Unmarshal(delivery.Body(), jobFinished); err != nil {
		log.Printf("Failed to parse message, not deleting logs: %v", err)
		return
	}

	_, err := c.redisStorage.DeleteLogs(context.Background(), jobFinished.JobId)
	if err != nil {
		log.Printf("Error deleting logs for %s from Redis: %v", jobFinished.JobId, err)
	}
}
