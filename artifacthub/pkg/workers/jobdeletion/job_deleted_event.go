package jobdeletion

import (
	"encoding/json"

	uuid "github.com/satori/go.uuid"
)

// JobDeletedEvent represents a job deletion event from zebra and will be replace with the 
// protobuf definition
type JobDeletedEvent struct {
	JobID          uuid.UUID `json:"job_id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	ProjectID      uuid.UUID `json:"project_id"`
}

func ParseJobDeletedEvent(raw []byte) (*JobDeletedEvent, error) {
	event := &JobDeletedEvent{}

	err := json.Unmarshal(raw, &event)
	if err != nil {
		return nil, err
	}

	return event, nil
}

func (e *JobDeletedEvent) ToJSON() ([]byte, error) {
	return json.Marshal(e)
}
