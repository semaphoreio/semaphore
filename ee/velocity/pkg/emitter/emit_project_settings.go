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

func (emitter *PendingMetricsEmitter) emitSetting(wg *sync.WaitGroup, settingsChan <-chan entity.ProjectSettings) {
	for settings := range settingsChan {
		emitter.processSetting(settings)
		wg.Done()
	}
}

func (emitter *PendingMetricsEmitter) processSetting(settings entity.ProjectSettings) {
	//define the date may be challenging as we can skip a day if there is a downtime that's more than 24h
	yesterday := time.Now().AddDate(0, 0, -1)

	message, err := emitter.buildSettingMessage(settings)
	if err != nil {
		emitter.increment("publish_message", []string{"fail"})
		log.Printf("failed to buildSettingMessage %v with error %v", settings, err)
		return
	}

	err = emitter.publishMessage(message)
	if err != nil {
		emitter.increment("publish_message", []string{"fail"})
		log.Printf("failed to publishMessage %v with error %v", message, err)
		return
	}
	log.Printf("Published settings (%s %s %s %s)",
		settings.ProjectId,
		settings.CdPipelineFileName,
		settings.CdBranchName,
		yesterday.Format("2006-01-02"))

	emitter.increment("publish_message", []string{"success"})
	return
}

func (emitter *PendingMetricsEmitter) buildSettingMessage(settings entity.ProjectSettings) ([]byte, error) {
	yesterday := time.Now().AddDate(0, 0, -1)

	describedProject, err := emitter.describeProject(settings.ProjectId)
	if err != nil {
		log.Printf("describing project failed %v", err)
		return nil, err
	}

	orgId := ""

	if describedProject != nil && describedProject.Project != nil && describedProject.Project.Metadata != nil {
		orgId = describedProject.Project.Metadata.OrgId
	}

	if len(orgId) == 0 {
		log.Printf("organization id is empty for project Id: %s", settings.ProjectId.String())
		return nil, fmt.Errorf("orgId is empty, project Id: %s", settings.ProjectId.String())
	}

	if !settings.HasCdBranch() {
		log.Printf("cd branch is empty for project Id: %s", settings.ProjectId.String())
		return nil, fmt.Errorf("cd branch is empty, project Id: %s", settings.ProjectId.String())
	}

	if !settings.HasCdPipelineFileName() {
		log.Printf("cd pipeline file name is empty for project Id: %s", settings.ProjectId.String())
		return nil, fmt.Errorf("cd pipeline file name is empty, project Id: %s", settings.ProjectId.String())
	}

	message, err := proto.Marshal(&protos.CollectPipelineMetricsEvent{
		ProjectId:        settings.ProjectId.String(),
		PipelineFileName: settings.CdPipelineFileName,
		BranchName:       settings.CdBranchName,
		MetricDay:        timestamppb.New(yesterday),
		Timestamp:        timestamppb.New(yesterday),
		OrganizationId:   orgId,
	})

	if err != nil {
		log.Printf("failed to marshal message, %v", err)
		return nil, err
	}

	return message, nil
}
