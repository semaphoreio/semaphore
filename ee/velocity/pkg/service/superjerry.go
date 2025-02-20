package service

import (
	"context"
	"log"
	"time"

	"github.com/semaphoreci/test-results/pkg/parser"
	"github.com/semaphoreio/semaphore/velocity/pkg/config"
	"github.com/semaphoreio/semaphore/velocity/pkg/protos/superjerry"
	"google.golang.org/grpc"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type SuperjerryGRPCClient struct {
	conn *grpc.ClientConn
}

type SuperjerryClient interface {
	SendReport(organizationId, projectId string, trs []parser.TestResults) error
}

func NewSuperjerryService(conn *grpc.ClientConn) SuperjerryClient {
	return &SuperjerryGRPCClient{conn: conn}
}

func (s *SuperjerryGRPCClient) SendReport(organizationId, projectId string, trs []parser.TestResults) error {
	client := superjerry.NewSuperjerryClient(s.conn)

	tCtx, cancel := context.WithTimeout(context.Background(), config.SuperjerryGrpcCallTimeout()*time.Second)
	defer cancel()

	request := createInsertTestResultsRequest(organizationId, projectId, trs)
	log.Printf("sending test results to superjerry: Org %s, project %s, len %d", request.OrgId, request.ProjectId, len(request.TestResults))
	_, err := client.InsertTestResults(tCtx, request)
	if err == nil {
		log.Printf("finished sending test results to superjerry: Org %s, project %s, len %d", request.OrgId, request.ProjectId, len(request.TestResults))
	}

	return err
}

func createInsertTestResultsRequest(orgId string, projectId string, testResults []parser.TestResults) *superjerry.InsertTestResultsRequest {
	results := makeTestResults(orgId, projectId, testResults)

	return &superjerry.InsertTestResultsRequest{
		OrgId:       orgId,
		ProjectId:   projectId,
		TestResults: results,
	}

}

func makeTestResults(orgId, projectId string, trs []parser.TestResults) []*superjerry.TestResult {
	var results []*superjerry.TestResult

	for _, tr := range trs {
		// Iterate through the results and write each test to the CSV file
		for _, suite := range tr.Suites {
			for _, test := range suite.Tests {

				results = append(results, &superjerry.TestResult{
					OrgId:      orgId,
					ProjectId:  projectId,
					Id:         test.ID,
					Name:       test.Name,
					Group:      test.Classname,
					Suite:      tr.Name,
					File:       test.File,
					Framework:  tr.Framework,
					Hash:       test.SemEnv.GitRefSha,
					Duration:   uint64(test.Duration / 1_000_000), //duration is in nanoseconds, convert to milliseconds
					RunId:      test.SemEnv.JobId,
					State:      string(test.State),
					RunAt:      timestamppb.New(time.Now()),
					Context:    test.SemEnv.GitRefName,
					InsertedAt: timestamppb.New(time.Now()),
				})
			}
		}
	}

	return results
}
