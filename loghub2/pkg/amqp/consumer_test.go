package amqp

import (
	"context"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/renderedtext/go-tackle"
	protos "github.com/semaphoreio/semaphore/loghub2/pkg/protos/server_farm.mq.job_state_exchange"
	"github.com/semaphoreio/semaphore/loghub2/pkg/storage"
	"github.com/stretchr/testify/assert"
	"google.golang.org/protobuf/proto"
)

var (
	TestBucketName = "amqp-test"
	TestQueueName  = "test-queue"
	TestProjectID  = uuid.NewString()
	TestLogs       = "line1\nline2\nline3\nline4\nline5\n"
)

var u, _ = url.Parse("http://gcs:4443/")
var httpClient = &http.Client{Transport: storage.RoundTripper(*u)}
var redisStorage = storage.NewRedisStorage(storage.RedisConfig{
	Address:  "redis",
	Port:     "6379",
	Username: "",
	Password: "",
})

var gcsStorage, _ = storage.NewGCSStorageWithClient(httpClient, TestBucketName)
var amqpConsumer = NewAmqpConsumer(redisStorage, gcsStorage)
var options = tackle.Options{
	URL:            "amqp://guest:guest@rabbitmq:5672",
	RemoteExchange: "test.remote-exchange",
	Service:        "test.service",
	RoutingKey:     "test-routing-key",
}

func Test__AmqpConsumerCanBeStartedAndStopped(t *testing.T) {
	go amqpConsumer.Start(&options)
	assert.Eventually(t, func() bool { return amqpConsumer.State() == tackle.StateListening }, time.Second, 100*time.Millisecond)
	amqpConsumer.Stop()
	assert.Eventually(t, func() bool { return amqpConsumer.State() == tackle.StateNotListening }, time.Second, 100*time.Millisecond)
}

func Test__AmqpConsumerCannotBeStartedTwice(t *testing.T) {
	go amqpConsumer.Start(&options)
	assert.Eventually(t, func() bool { return amqpConsumer.State() == tackle.StateListening }, time.Second, 100*time.Millisecond)

	err := amqpConsumer.Start(&options)
	assert.NotNil(t, err)
	amqpConsumer.Stop()
}

func Test__WhenJobIsDone(t *testing.T) {
	go amqpConsumer.Start(&options)
	err := gcsStorage.CreateBucket(TestBucketName, TestProjectID)
	assert.Nil(t, err)

	t.Run("LogsAreRemovedFromRedis", LogsAreRemovedFromRedis)
	t.Run("LogsArePushedToGCS", LogsArePushedToGCS)
	t.Run("LogsAreNotPushedToGCSIfNoneFoundInRedis", LogsAreNotPushedToGCSIfNoneFoundInRedis)
	t.Run("MessageIsIgnoredIfSelfHostedIsFalse", MessageIsIgnoredIfSelfHostedIsFalse)

	amqpConsumer.Stop()
	err = gcsStorage.DeleteBucket(TestBucketName)
	assert.Nil(t, err)
}

func Test__LogsAreDeletedFromRedisIfMessageGoesToDeadQueue(t *testing.T) {
	var badStorage, _ = storage.NewGCSStorageWithClient(httpClient, "this-bucket-does-not-exist")
	var consumerWithBadBucket = NewAmqpConsumer(redisStorage, badStorage)
	go consumerWithBadBucket.Start(&tackle.Options{
		URL:            "amqp://guest:guest@rabbitmq:5672",
		RemoteExchange: "test.remote-exchange",
		Service:        "test.service",
		RoutingKey:     "test-routing-key",
		RetryDelay:     1,
		RetryLimit:     1,
	})

	jobId := "LogsAreDeletedFromRedisIfMessageGoesToDeadQueue"
	err := redisStorage.AppendLogs(jobId, 0, strings.Split(TestLogs, "\n"))
	assert.Nil(t, err)
	assert.True(t, redisStorage.JobIdExists(context.Background(), jobId))

	err = publishMessage(jobId, true)
	assert.Nil(t, err)
	assert.Eventually(t, func() bool { return !redisStorage.JobIdExists(context.Background(), jobId) }, 2*time.Second, 500*time.Millisecond)

	consumerWithBadBucket.Stop()
}

func LogsAreRemovedFromRedis(t *testing.T) {
	jobId := "LogsAreRemovedFromRedis"
	err := redisStorage.AppendLogs(jobId, 0, strings.Split(TestLogs, "\n"))
	assert.Nil(t, err)
	assert.True(t, redisStorage.JobIdExists(context.Background(), jobId))

	err = publishMessage(jobId, true)
	assert.Nil(t, err)
	assert.Eventually(t, func() bool { return !redisStorage.JobIdExists(context.Background(), jobId) }, time.Second, 100*time.Millisecond)
}

func LogsArePushedToGCS(t *testing.T) {
	jobId := "LogsArePushedToGCS"
	err := redisStorage.AppendLogs(jobId, 0, strings.Split(TestLogs, "\n"))
	assert.Nil(t, err)
	exists, err := gcsStorage.Exists(context.Background(), jobId)
	assert.False(t, exists)
	assert.NotNil(t, err)

	err = publishMessage(jobId, true)
	assert.Nil(t, err)
	assert.Eventually(t, func() bool { exists, _ := gcsStorage.Exists(context.Background(), jobId); return exists }, time.Second, 100*time.Millisecond)

	fileContent, err := gcsStorage.ReadFile(context.Background(), jobId)
	assert.Nil(t, err)

	rawContent, err := storage.Gunzip(fileContent)
	assert.Nil(t, err)
	assert.Equal(t, TestLogs, string(rawContent))
}

func LogsAreNotPushedToGCSIfNoneFoundInRedis(t *testing.T) {
	jobId := "this-job-does-not-exist"
	err := publishMessage(jobId, true)
	assert.Nil(t, err)
	assert.Never(t, func() bool { exists, _ := gcsStorage.Exists(context.Background(), jobId); return exists }, time.Second, 100*time.Millisecond)
}

func MessageIsIgnoredIfSelfHostedIsFalse(t *testing.T) {
	jobId := "hosted-job"
	err := publishMessage(jobId, false)
	assert.Nil(t, err)
	assert.Never(t, func() bool { exists, _ := gcsStorage.Exists(context.Background(), jobId); return exists }, time.Second, 100*time.Millisecond)
}

func publishMessage(jobId string, selfHosted bool) error {
	config := amqp.Config{Properties: amqp.NewConnectionProperties()}
	config.Properties.SetClientConnectionName("loghub2")

	connection, err := amqp.DialConfig(options.URL, config)
	if err != nil {
		return err
	}

	defer connection.Close()

	channel, err := connection.Channel()
	if err != nil {
		return err
	}

	defer channel.Close()

	err = channel.ExchangeDeclare(options.RemoteExchange, "direct", true, false, false, false, nil)
	if err != nil {
		return err
	}

	jobFinished := &protos.JobFinished{JobId: jobId, SelfHosted: selfHosted}
	data, err := proto.Marshal(jobFinished)
	if err != nil {
		return err
	}

	err = channel.Publish(options.RemoteExchange, options.RoutingKey, false, false, amqp.Publishing{Body: data})
	if err != nil {
		return err
	}

	return nil
}
