package entity

import (
	"log"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/velocity/pkg/database"
	"github.com/stretchr/testify/assert"
)

func TestListPendingMetrics(t *testing.T) {
	tests := []struct {
		name              string
		projectID         uuid.UUID
		pipelineFileNames []string
		days              int
		pipelines         int
		expectedLength    int
	}{
		{
			name:              "Empty results",
			projectID:         uuid.New(),
			pipelineFileNames: []string{},
			days:              0,
			pipelines:         10,
			expectedLength:    0,
		},
		{
			name:              "One pipeline file, one day",
			projectID:         uuid.New(),
			pipelineFileNames: []string{".semaphore/semaphore.yml"},
			days:              1,
			pipelines:         1,
			expectedLength:    1,
		},
		{
			name:              "One pipeline file,  multiple days",
			projectID:         uuid.New(),
			pipelineFileNames: []string{".semaphore/semaphore.yml"},
			days:              10,
			pipelines:         5,
			expectedLength:    10,
		},
		{
			name:              "One pipeline file, multiple days",
			projectID:         uuid.New(),
			pipelineFileNames: []string{".semaphore/semaphore.yml"},
			days:              10,
			pipelines:         5,
			expectedLength:    10,
		},
		{
			name:              "Multiple pipeline files, multiple days",
			projectID:         uuid.New(),
			pipelineFileNames: []string{".semaphore/semaphore.yml", ".semaphore/promotion.yml"},
			days:              10,
			pipelines:         5,
			expectedLength:    20,
		},
	}

	for _, tt := range tests {
		database.Truncate(PipelineRun{}.TableName())

		for _, pipelineFile := range tt.pipelineFileNames {
			for daysAgo := 1; daysAgo < tt.days+1; daysAgo++ {
				for j := 0; j < tt.pipelines; j++ {
					CreateDummyPipelineRun(tt.projectID, pipelineFile, time.Now().AddDate(0, 0, -daysAgo))
				}
			}
		}

		t.Run(tt.name, func(t *testing.T) {
			pipelineMetrics, err := ListPendingMetrics()
			log.Println(pipelineMetrics)
			assert.Nil(t, err)
			assert.Equal(t, tt.expectedLength, len(pipelineMetrics))
		})
	}
}
