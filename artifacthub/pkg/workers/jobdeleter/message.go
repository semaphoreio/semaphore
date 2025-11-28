package jobdeleter

import (
	"encoding/json"
	"fmt"
)

// Message describes a request to delete artifacts produced by a job.
type Message struct {
	ArtifactID string `json:"artifact_id"`
	JobID      string `json:"job_id"`
}

// ParseMessage converts the raw queue payload into a strongly typed structure.
func ParseMessage(payload []byte) (*Message, error) {
	var msg Message

	if err := json.Unmarshal(payload, &msg); err != nil {
		return nil, fmt.Errorf("failed to unmarshal job artifact delete message: %w", err)
	}

	if msg.ArtifactID == "" {
		return nil, fmt.Errorf("invalid job artifact delete message: artifact_id is empty")
	}

	if msg.JobID == "" {
		return nil, fmt.Errorf("invalid job artifact delete message: job_id is empty")
	}

	return &msg, nil
}
