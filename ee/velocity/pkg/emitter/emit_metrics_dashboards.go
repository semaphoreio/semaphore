package emitter

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/golang/protobuf/proto"
	"github.com/semaphoreio/semaphore/velocity/pkg/entity"
	protos "github.com/semaphoreio/semaphore/velocity/pkg/protos/velocity"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func (emitter *PendingMetricsEmitter) emitMetricsDashboardSettings(wg *sync.WaitGroup, dashboardsChan <-chan entity.MetricsDashboard) {
	for dashboard := range dashboardsChan {
		emitter.processDashboardSettings(dashboard)
		wg.Done()
	}
}

func (emitter *PendingMetricsEmitter) processDashboardSettings(dashboard entity.MetricsDashboard) {
	yesterday := time.Now().AddDate(0, 0, -1)
	mergedSettings := generateMergedMetricsSettings(dashboard)
	for _, item := range mergedSettings {
		message, err := buildMetricsDashboardMessage(item)
		if err != nil {
			emitter.increment("publish_message", []string{"fail"})
			log.Printf("failed to buildMetricsDashboardMessage with error %v", err)
			continue
		}

		err = emitter.publishMessage(message)
		if err != nil {
			emitter.increment("publish_message", []string{"fail"})
			log.Printf("failed to publishMessage with error %v", err)
			continue
		}

		log.Printf("Published custom dashboard metric (%s %s %s %s)",
			item.ProjectId,
			item.PipelineFileName,
			item.BranchName,
			yesterday.Format("2006-01-02"))
		emitter.increment("publish_message", []string{"success"})
	}
}

func buildMetricsDashboardMessage(mergedItem mergedMetricsSettings) ([]byte, error) {
	yesterday := time.Now().AddDate(0, 0, -1)

	if len(mergedItem.PipelineFileName) == 0 {
		log.Printf("pipeline file name is empty, for project id %v", mergedItem.ProjectId)
		return nil, fmt.Errorf("pipeline file name is empty")
	}

	message, err := proto.Marshal(&protos.CollectPipelineMetricsEvent{
		ProjectId:        mergedItem.ProjectId,
		OrganizationId:   mergedItem.OrganizationId,
		PipelineFileName: mergedItem.PipelineFileName,
		BranchName:       mergedItem.BranchName,
		MetricDay:        timestamppb.New(yesterday),
		Timestamp:        timestamppb.New(yesterday),
	})

	return message, err
}

type mergedMetricsSettings struct {
	ProjectId        string
	OrganizationId   string
	PipelineFileName string
	BranchName       string
}

func generateMergedMetricsSettings(dashboard entity.MetricsDashboard) []mergedMetricsSettings {
	mergedSettings := make([]mergedMetricsSettings, 0)

	projectId := dashboard.ProjectId.String()
	organizationId := dashboard.OrganizationId.String()

	type Key struct {
		PipelineFileName string
		BranchName       string
	}

	registry := make(map[Key]bool)

	for _, item := range dashboard.Items {
		registry[Key{item.PipelineFileName, item.BranchName}] = true
	}

	for key := range registry {
		mergedSettings = append(mergedSettings, mergedMetricsSettings{
			ProjectId:        projectId,
			OrganizationId:   organizationId,
			PipelineFileName: key.PipelineFileName,
			BranchName:       key.BranchName,
		})
	}

	return mergedSettings
}
