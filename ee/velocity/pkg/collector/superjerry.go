// Package collector holds the pipeline done collector.
package collector

import (
	"bufio"
	"errors"
	"io"
	"log"
	"net/http"
	"reflect"
	"time"

	"github.com/bytedance/sonic"
	"github.com/google/uuid"

	"github.com/golang/protobuf/proto"
	"github.com/renderedtext/go-tackle"
	"github.com/renderedtext/go-watchman"
	"github.com/semaphoreci/test-results/pkg/parser"
	"github.com/semaphoreio/semaphore/velocity/pkg/compression"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	"github.com/semaphoreio/semaphore/velocity/pkg/feature"
	serverfarm "github.com/semaphoreio/semaphore/velocity/pkg/protos/server_farm.job"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"github.com/semaphoreio/semaphore/velocity/pkg/retry"
	"github.com/semaphoreio/semaphore/velocity/pkg/service"
)

var ErrNotFound = errors.New("not found")

type Superjerry struct {
	reportFetcherClient service.ReportFetcherClient
	projectHubClient    service.ProjectHubClient
	superjerryClient    service.SuperjerryClient
	featureHubClient    service.FeatureHubClient
	serverFarmClient    service.ServerFarmClient
}

func StartSuperjerryCollector(options *tackle.Options, projectHubClient service.ProjectHubClient, serverFarmClient service.ServerFarmClient, featureHubClient service.FeatureHubClient, reportFetcherClient service.ReportFetcherClient, sjClient service.SuperjerryClient) {
	log.Println("Starting superjerry collector")
	collector := Superjerry{
		reportFetcherClient: reportFetcherClient,
		superjerryClient:    sjClient,
		serverFarmClient:    serverFarmClient,
		featureHubClient:    featureHubClient,
		projectHubClient:    projectHubClient,
	}

	consumer := tackle.NewConsumer()

	err := retry.WithConstantWait("RabbitMQ conn", ConnectionRetries, ConnectionRetryWaitDuration, func() error {
		return consumer.Start(options, collector.Collect)
	})

	if err != nil {
		log.Fatalf("err starting superjerry collector, %v", err)
	}
}

func (c *Superjerry) Collect(delivery tackle.Delivery) (err error) {
	defer watchman.Benchmark(time.Now(), "velocity.superjerry_collector.execution")
	defer func() {
		if err != nil {
			_ = watchman.Increment("velocity.superjerry_collector.failure")
		} else {
			_ = watchman.Increment("velocity.superjerry_collector.success")
		}
	}()

	jobSummaryAvailableEvent := &protos.JobSummaryAvailableEvent{}
	err = proto.Unmarshal(delivery.Body(), jobSummaryAvailableEvent)
	if err != nil {
		return
	}

	jobID := jobSummaryAvailableEvent.JobId
	organizationID, projectID, err := c.fetchJobDetails(jobID)

	enabled, err := c.checkFeatureEnabled(organizationID)
	if err != nil {
		return err
	}

	if !enabled {
		return nil
	}

	withinLimit, err := c.reportWithinSizeLimit(jobID, 50_000)
	if err != nil {
		return err
	}

	if !withinLimit {
		return nil
	}

	log.Printf("Received collect request for job %s\n", jobSummaryAvailableEvent.JobId)

	results, err := c.prepareReport(projectID, jobID)
	if err != nil {
		if errors.Is(err, ErrNotFound) {
			log.Printf("No report found for job: %s\n", jobID)
			_ = watchman.Increment("velocity.superjerry_collector.no_report")
			return nil
		}
		if errors.Is(err, compression.ErrSizeLimitReached) {
			log.Printf("Report too large for job: %s\n", jobID)
			_ = watchman.IncrementWithTags("velocity.superjerry_collector.report_too_large", []string{jobID})
			return nil
		}
		return err
	}

	log.Printf("Sending report to superjerry for organization: %s, project: %s\n, job: %s", organizationID, projectID, jobID)
	err = c.superjerryClient.SendReport(organizationID, projectID, results)
	if err != nil {
		return err
	}

	return
}

func (c *Superjerry) fetchJobDetails(jobID string) (string, string, error) {
	if len(jobID) == 0 {
		return "", "", errors.New("missing job identifier")
	}

	request := serverfarm.DescribeRequest{
		JobId: jobID,
	}

	response, err := c.serverFarmClient.Describe(&request)
	if err != nil {
		return "", "", err
	}

	organizationID := response.Job.OrganizationId
	projectID := response.Job.ProjectId

	return organizationID, projectID, nil
}

func (c *Superjerry) checkFeatureEnabled(organizationID string) (bool, error) {
	state, err := c.featureHubClient.FeatureState(organizationID, "superjerry_tests")
	if err != nil {
		return false, err
	}

	if state == feature.ZeroState || state == feature.Enabled {
		return true, nil
	}

	return false, nil
}

// reportWithinSizeLimit checks if the report has at most `limit` number of tests
func (c *Superjerry) reportWithinSizeLimit(jobID string, limit int) (bool, error) {
	summary, err := entity.FindJobSummary(uuid.MustParse(jobID))
	if err != nil {
		return false, err
	}

	return summary.Total <= limit, nil
}

func (c *Superjerry) prepareReport(projectID string, jobID string) ([]parser.TestResults, error) {
	artifactStoreId, err := c.fetchArtifactStoreId(projectID)
	if err != nil {
		return nil, err
	}

	url, err := c.reportFetcherClient.GetJobReportURL(artifactStoreId, jobID)
	if err != nil {
		return nil, err
	}

	log.Printf("Fetching report for job: %s\n", jobID)
	response, err := http.Get(url) // #nosec
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()

	if response.StatusCode == http.StatusNotFound {
		return nil, ErrNotFound
	}

	bufferedReader := bufio.NewReader(response.Body)
	reportReader, err := compression.GzipDecompress(bufferedReader, 1024*1024*50) // 50MB max size
	if err != nil {
		return nil, err
	}

	log.Printf("Decoding report from job: %s\n", jobID)
	var results parser.Result
	err = sonic.Pretouch(reflect.TypeOf(results))
	if err != nil {
		return nil, err
	}

	// Create a buffer to read all data first, so we can detect size limit errors
	data, err := io.ReadAll(reportReader)
	if err != nil {
		if errors.Is(err, compression.ErrSizeLimitReached) {
			log.Printf("Report exceeds 50MB limit for job: %s", jobID)
			return nil, compression.ErrSizeLimitReached
		}
		return nil, err
	}

	err = sonic.Unmarshal(data, &results)
	if err != nil {
		return nil, err
	}

	log.Printf("Processing %d test results\n", len(results.TestResults))

	return results.TestResults, nil
}

func (c *Superjerry) fetchArtifactStoreId(projectId string) (string, error) {
	project, err := c.projectHubClient.Describe(&service.ProjectHubDescribeOptions{ProjectID: projectId})
	if err != nil {
		return "", err
	}

	if project == nil {
		return "", errors.New("project is nil")
	}
	if project.Project == nil {
		return "", errors.New("project.Project is nil")
	}
	if project.Project.Spec == nil {
		return "", errors.New("project.Project.Spec is nil")
	}

	return project.Project.Spec.ArtifactStoreId, nil
}
