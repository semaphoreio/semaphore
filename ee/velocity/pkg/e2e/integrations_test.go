package e2e

import (
	"fmt"
	"log"
	"os"
	"testing"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/google/uuid"
	"github.com/renderedtext/go-tackle"
	"github.com/semaphoreio/semaphore/velocity/pkg/aggregator"
	"github.com/semaphoreio/semaphore/velocity/pkg/collector"
	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/semaphoreio/semaphore/velocity/pkg/emitter"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/options"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/plumber.pipeline"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
	"github.com/semaphoreio/semaphore/velocity/test/support"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func TestNewPipelineDoneMessageReceived(t *testing.T) {
	err := database.Truncate(entity.PipelineRun{}.TableName())
	require.Nil(t, err)

	cl := collector.PipelineDone{PlumberClient: service.NewPlumberService(testConn), ProjectHubClient: service.NewProjectHubService(testConn)}
	consumer := tackle.NewConsumer()
	defer consumer.Stop()

	recentQueue := options.Recent()
	go retry.WithConstantWait("RabbitMQ conn", collector.ConnectionRetries, collector.ConnectionRetryWaitDuration, func() error {
		return consumer.Start(&recentQueue, cl.Collect)
	})

	assert.Eventually(t, func() bool {
		return consumer.State == tackle.StateListening
	}, 2*time.Second, 200*time.Millisecond)

	var initialCount int64
	database.Conn().Model(entity.PipelineRun{}).Count(&initialCount)
	require.Equal(t, int64(0), initialCount, "pipeline run should not have any rows")

	pplId := uuid.NewString()
	newPipelineDoneEvent(t, pplId, recentQueue)

	assert.Eventually(t, func() bool {
		var afterEventCount int64
		database.Conn().Model(entity.PipelineRun{}).Count(&afterEventCount)
		return afterEventCount > 0
	}, 4*time.Second, 500*time.Millisecond)
}

func TestEmitterSendsMessageForCIAndCDBranch(t *testing.T) {
	err := database.Truncate(entity.PipelineRun{}.TableName())
	require.Nil(t, err)

	// Start pipeline run consumer
	projectHub := service.NewProjectHubService(testConn)
	cl := collector.PipelineDone{PlumberClient: service.NewPlumberService(testConn), ProjectHubClient: projectHub}
	consumer := tackle.NewConsumer()
	defer consumer.Stop()

	recentQueue := options.Recent()
	go retry.WithConstantWait("RabbitMQ conn", collector.ConnectionRetries, collector.ConnectionRetryWaitDuration, func() error {
		return consumer.Start(&recentQueue, cl.Collect)
	})

	require.Eventually(t, func() bool {
		return consumer.State == tackle.StateListening
	}, 2*time.Second, 200*time.Millisecond)

	// Start project metrics aggregator
	aggregator := aggregator.NewProjectMetricsAggregator(options.CollectPipelineMetricsDoneEvent())
	defer aggregator.Stop()
	go aggregator.Start()

	require.Eventually(t, func() bool {
		return aggregator.State() == tackle.StateListening
	}, 2*time.Second, 200*time.Millisecond)

	// Assert there are no pipeline runs yet
	var initialCount int64
	database.Conn().Model(entity.PipelineRun{}).Count(&initialCount)
	require.Equal(t, int64(0), initialCount, "pipeline run should not have any rows")

	// Send 10 pipeline done events
	for i := 0; i < 50; i++ {
		pplId := uuid.NewString()
		newPipelineDoneEvent(t, pplId, recentQueue)
	}

	// Assert the pipeline runs are saved in DB
	require.Eventually(t, func() bool {
		var afterEventCount int64
		database.Conn().Model(entity.PipelineRun{}).Count(&afterEventCount)
		return afterEventCount == 50
	}, 4*time.Second, 500*time.Millisecond)

	// Create project settings and start emitter
	require.NoError(t, database.Truncate(entity.ProjectSettings{}.TableName()))
	projectID, err := uuid.Parse(support.FakeProjectId)
	require.NoError(t, err)

	ps := entity.ProjectSettings{
		ProjectId:          projectID,
		CiBranchName:       "master",
		CiPipelineFileName: "semaphore.yml",
		CdBranchName:       "deploy",
		CdPipelineFileName: "deploy.yml",
		OrganizationId:     uuid.New(),
	}

	require.NoError(t, database.Conn().Create(&ps).Error)
	metricsEmitter := emitter.NewPendingMetricsEmitter(options.CollectPipelineMetricsDoneEvent(), projectHub, "* * * * *")
	metricsEmitter.PublishPendingMetrics()

	// Assert we have a metric for CI and for CD
	assert.Eventually(t, func() bool {
		ciMetrics, err := entity.ListProjectMetricsBy(entity.ProjectMetricsFilter{
			ProjectId:        projectID,
			BranchName:       "master",
			PipelineFileName: "semaphore.yml",
		})

		require.NoError(t, err)

		cdMetrics, err := entity.ListProjectMetricsBy(entity.ProjectMetricsFilter{
			ProjectId:        projectID,
			BranchName:       "deploy",
			PipelineFileName: "deploy.yml",
		})

		require.NoError(t, err)

		fmt.Printf("CI metrics: %v\n", ciMetrics)
		fmt.Printf("CD metrics: %v\n", cdMetrics)

		return len(ciMetrics) > 0 && len(cdMetrics) > 0
	}, 4*time.Second, 500*time.Millisecond)
}

func newPipelineDoneEvent(t *testing.T, id string, options tackle.Options) {
	pplDone := &pb.PipelineEvent{
		PipelineId: id,
		State:      pb.Pipeline_DONE,
	}

	body, err := proto.Marshal(pplDone)
	require.Nil(t, err)

	err = tackle.PublishMessage(&tackle.PublishParams{
		Body:       body,
		AmqpURL:    options.URL,
		RoutingKey: options.RoutingKey,
		Exchange:   options.RemoteExchange,
	})

	require.Nil(t, err)
}

var testConn *grpc.ClientConn

func TestMain(m *testing.M) {
	support.StartFakeServers()
	// Give some time for the server to start
	time.Sleep(5 * time.Second)

	conn, err := grpc.Dial(fmt.Sprintf("0.0.0.0:%d", config.FakeServerPortInTests), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("error opening connection to local GPRC server: %v", err)
	}
	defer func(conn *grpc.ClientConn) {
		err := conn.Close()
		if err != nil {
			log.Fatalf("failed to close grpc conn: %v", err)
		}
	}(conn)

	testConn = conn

	os.Exit(m.Run())
}
