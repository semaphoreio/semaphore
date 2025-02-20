package api

import (
	"context"
	"errors"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/renderedtext/go-watchman"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	s "github.com/semaphoreio/semaphore/velocity/pkg/service"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (p velocityService) FetchOrganizationHealth(ctx context.Context, request *pb.OrganizationHealthRequest) (*pb.OrganizationHealthResponse, error) {
	defer watchman.Benchmark(time.Now(), "velocity.pipeline_metrics.FetchOrganizationHealth")
	log.Printf("FetchOrganizationHealth %v", request.ProjectIds)

	if len(request.ProjectIds) == 0 {
		return nil, errors.New("no project ids provided")
	}

	projectIDs := make([]uuid.UUID, 0)
	for _, p := range request.ProjectIds {
		v, e := uuid.Parse(p)
		if e == nil {
			projectIDs = append(projectIDs, v)
		}
	}

	metrics, err := s.FetchOrganizationHealthByProjectIDs(s.FetchOrganizationHealthOptions{
		ProjectHubClient: p.projectHub,
		OrganizationId:   request.OrgId,
		ProjectIDs:       projectIDs,
		From:             request.FromDate.AsTime(),
		To:               request.ToDate.AsTime(),
	})
	if err != nil {
		log.Printf("Failed to fetch Org Health metrics %v with %v", request.ProjectIds, err)
		return nil, err
	}

	return &pb.OrganizationHealthResponse{
		HealthMetrics: buildProjectMetrics(metrics),
	}, nil
}

func buildProjectMetrics(oh *s.OrganizationHealth) []*pb.ProjectHealthMetrics {
	result := make([]*pb.ProjectHealthMetrics, 0, len(oh.HealthMetrics))
	for _, opm := range oh.HealthMetrics {
		result = append(result, &pb.ProjectHealthMetrics{
			ProjectId:                 opm.ProjectId,
			ProjectName:               opm.ProjectName,
			MeanTimeToRecoverySeconds: 0,
			LastSuccessfulRunAt:       timestamppb.New(opm.LastSuccessfulRun),
			DefaultBranch:             buildStats(opm.DefaultBranchHealth),
			AllBranches:               buildStats(opm.AllBranchesHealth),
			Parallelism:               0,
			Deployments:               0,
		})
	}

	return result
}

func buildStats(stats s.BranchHealth) *pb.Stats {
	return &pb.Stats{
		AllCount:                   stats.TotalRuns,
		PassedCount:                stats.PassedRuns,
		FailedCount:                stats.FailedRuns,
		AvgSeconds:                 stats.AverageRunTime,
		AvgSecondsSuccessful:       stats.AverageRunTimeForSuccessfulRuns,
		QueueTimeSeconds:           0,
		QueueTimeSecondsSuccessful: 0,
	}
}
