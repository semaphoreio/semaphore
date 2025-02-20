package service

import (
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/samber/lo"
	lop "github.com/samber/lo/parallel"
	"github.com/semaphoreio/semaphore/velocity/pkg/calc"
	e "github.com/semaphoreio/semaphore/velocity/pkg/entity"
)

// Path: pkg/service/organization_health.go

type OrganizationHealth struct {
	OrganizationId string
	HealthMetrics  []ProjectHealth
}

type ProjectHealth struct {
	ProjectId          string
	ProjectName        string
	MeanTimeToRecovery time.Duration
	LastSuccessfulRun  time.Time
	Parallelism        int32
	Deployments        int32

	DefaultBranchHealth BranchHealth
	AllBranchesHealth   BranchHealth
}

type BranchHealth struct {
	BranchName                      string
	TotalRuns                       int32
	PassedRuns                      int32
	FailedRuns                      int32
	AverageRunTime                  int32
	AverageRunTimeForSuccessfulRuns int32
}

type FetchOrganizationHealthOptions struct {
	ProjectHubClient *ProjectHubGrpcClient
	OrganizationId   string
	ProjectIDs       []uuid.UUID
	From             time.Time
	To               time.Time
}

func FetchOrganizationHealthByProjectIDs(options FetchOrganizationHealthOptions) (*OrganizationHealth, error) {
	result := &OrganizationHealth{
		OrganizationId: options.OrganizationId,
		HealthMetrics:  make([]ProjectHealth, 0),
	}

	//get all projects
	ps, err := options.ProjectHubClient.ListAll(options.OrganizationId)

	if err != nil {
		return nil, err
	}

	projects := lo.Associate(ps, func(project *Project) (uuid.UUID, Project) {
		return project.Id, *project
	})

	//dependency = default branch
	allProjectMetricsForPeriod, err := e.ListProjectMetrics(e.ListFilter{
		ProjectIDs: options.ProjectIDs,
		BeginDate:  options.From,
		EndDate:    options.To,
	})

	log.Printf("Project Metrics Len(%d)", len(allProjectMetricsForPeriod))
	if err != nil {
		return nil, err
	}

	s, err := e.FindLastSuccessfulRuns(options.ProjectIDs)
	if err != nil {
		log.Printf("finding last successful run for project %s failed, %v", options.ProjectIDs, err)
	}

	lastSuccessfulRuns := lo.Associate(s, func(item e.ProjectLastSuccessfulRun) (uuid.UUID, e.ProjectLastSuccessfulRun) {
		return item.ProjectId, item
	})

	se, err := e.ProjectSettingsByProjectIDs(options.ProjectIDs)
	if err != nil {
		log.Printf("finding project settings for projects %v failed, %v", options.ProjectIDs, err)
	}

	projectSettings := lo.Associate(se, func(item *e.ProjectSettings) (uuid.UUID, *e.ProjectSettings) {
		return item.ProjectId, item
	})

	//group by branch
	projectMetricsAllBranches := lo.Filter(allProjectMetricsForPeriod, func(metrics e.ProjectMetrics, _ int) bool {
		return len(metrics.BranchName) == 0
	})

	projectMetricsOtherBranches := lo.Filter(allProjectMetricsForPeriod, func(metrics e.ProjectMetrics, _ int) bool {
		return len(metrics.BranchName) > 0
	})

	//group by project id
	AllBranchMetricsGroupedByProject := lo.GroupBy(projectMetricsAllBranches, func(item e.ProjectMetrics) uuid.UUID {
		return item.ProjectId
	})

	OtherBranchMetricsGroupedByProject := make(map[uuid.UUID][]e.ProjectMetrics, 0)

	for _, pm := range projectMetricsOtherBranches {
		setting := projectSettings[pm.ProjectId]
		defaultBranchName := defaultBranch(setting, projects[pm.ProjectId])

		if pm.BranchName == defaultBranchName {
			OtherBranchMetricsGroupedByProject[pm.ProjectId] = append(OtherBranchMetricsGroupedByProject[pm.ProjectId], pm)
		}
	}

	h := lop.Map(options.ProjectIDs, func(projectId uuid.UUID, _ int) *ProjectHealth {
		if _, ok := projects[projectId]; !ok {
			return nil
		}

		project := projects[projectId]

		healthAllBranches := AllBranchMetricsGroupedByProject[projectId]

		healthDefaultBranch := OtherBranchMetricsGroupedByProject[projectId]

		lastSuccessfulRun := time.Time{}
		if run, ok := lastSuccessfulRuns[projectId]; ok {
			lastSuccessfulRun = run.LastSuccessfulRunAt
		}

		return &ProjectHealth{
			ProjectId:           projectId.String(),
			ProjectName:         project.Name,
			MeanTimeToRecovery:  0,
			LastSuccessfulRun:   lastSuccessfulRun,
			Parallelism:         0,
			Deployments:         0,
			DefaultBranchHealth: buildBranchHealth(healthDefaultBranch),
			AllBranchesHealth:   buildBranchHealth(healthAllBranches),
		}
	})
	cleanedProjectHealth := lo.Reject(h, func(item *ProjectHealth, _ int) bool {
		return item == nil
	})

	healthPerProject := lo.Map(cleanedProjectHealth, func(item *ProjectHealth, _ int) ProjectHealth {
		return *item
	})

	result.HealthMetrics = healthPerProject

	return result, nil
}

func buildBranchHealth(m []e.ProjectMetrics) BranchHealth {

	total := lo.Reduce(m, func(agg int32, item e.ProjectMetrics, _ int) int32 {
		return agg + item.Metrics.All.Frequency.Count
	}, int32(0))

	passed := lo.Reduce(m, func(agg int32, item e.ProjectMetrics, _ int) int32 {
		return agg + item.Metrics.Passed.Frequency.Count
	}, int32(0))

	averageRunTime := calc.AverageFunc(m, func(m e.ProjectMetrics) int32 {
		return m.Metrics.All.Performance.Avg
	})

	averageRunTimeForSuccessfulRuns := calc.AverageFunc(m, func(m e.ProjectMetrics) int32 {
		return m.Metrics.Passed.Performance.Avg
	})

	return BranchHealth{
		TotalRuns:                       total,
		PassedRuns:                      passed,
		FailedRuns:                      total - passed,
		AverageRunTime:                  averageRunTime,
		AverageRunTimeForSuccessfulRuns: averageRunTimeForSuccessfulRuns,
	}
}

func defaultBranch(setting *e.ProjectSettings, project Project) string {
	if setting != nil && setting.HasCiBranch() {
		return setting.CiBranchName
	}

	if len(project.DefaultBranch) > 0 {
		return project.DefaultBranch
	}

	log.Printf("missing default branch for project %s", project.Id)
	return "main"
}
