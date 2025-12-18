package jobdeletion

import (
	"testing"

	uuid "github.com/satori/go.uuid"
	"github.com/stretchr/testify/assert"
)

func TestParseJobDeletedEvent(t *testing.T) {
	jobID := uuid.NewV4()
	orgID := uuid.NewV4()
	projectID := uuid.NewV4()

	jsonMsg := `{
		"job_id": "` + jobID.String() + `",
		"organization_id": "` + orgID.String() + `",
		"project_id": "` + projectID.String() + `"
	}`

	event, err := ParseJobDeletedEvent([]byte(jsonMsg))

	assert.NoError(t, err)
	assert.NotNil(t, event)
	assert.Equal(t, jobID, event.JobID)
	assert.Equal(t, orgID, event.OrganizationID)
	assert.Equal(t, projectID, event.ProjectID)
}

func TestParseJobDeletedEvent_InvalidJSON(t *testing.T) {
	event, err := ParseJobDeletedEvent([]byte("invalid json"))

	assert.Error(t, err)
	assert.Nil(t, event)
}

func TestJobDeletedEventToJSON(t *testing.T) {
	event := &JobDeletedEvent{
		JobID:          uuid.NewV4(),
		OrganizationID: uuid.NewV4(),
		ProjectID:      uuid.NewV4(),
	}

	jsonBytes, err := event.ToJSON()

	assert.NoError(t, err)
	assert.NotNil(t, jsonBytes)

	parsed, err := ParseJobDeletedEvent(jsonBytes)
	assert.NoError(t, err)
	assert.Equal(t, event.JobID, parsed.JobID)
	assert.Equal(t, event.OrganizationID, parsed.OrganizationID)
	assert.Equal(t, event.ProjectID, parsed.ProjectID)
}
