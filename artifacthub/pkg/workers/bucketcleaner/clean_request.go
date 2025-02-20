package bucketcleaner

import (
	"encoding/json"

	uuid "github.com/satori/go.uuid"
)

//
// The CleanRequest is the primary message for communicating between
// the scheduler and the workers.
//
// +-----------+                +---------+
// | Scheduler | ---> AMQP ---> | Workers | ----+
// +-----------+       ^        +---------+     |
//                     |                        |
//                     |                        |
//                     +------------------------+
//
// The scheduler initializes the work process.
// The worker clean up a batch, and then schedules a new batch until the whole bucket is processed.
//
// --------------
//
// The communication is started by the scheduler who initiates a
// cleaning for a bucket.
//
// 1. First message
//    Scheduler -> AMQP -> Worker: {"artifact_bucket_id": ID, pagination_token: ""}
//
// *. The next messages go from Worker to Worker
//    Worker -> AMQP -> Worker: {"artifact_bucket_id": ID, pagination_token: "... token ..."}
//
// N. When the worker reaches the end of the bucket, it will no longer send a message to the amqp queue.
//

type CleanRequest struct {
	ArtifactBucketID uuid.UUID `json:"artifact_bucket_id"`
	PaginationToken  string    `json:"pagination_token"`
}

func NewCleanRequest(artifactID string) (*CleanRequest, error) {
	id, err := uuid.FromString(artifactID)
	if err != nil {
		return nil, err
	}

	return &CleanRequest{ArtifactBucketID: id}, nil
}

func ParseCleanRequest(raw []byte) (*CleanRequest, error) {
	request := &CleanRequest{}

	err := json.Unmarshal(raw, &request)
	if err != nil {
		return nil, err
	}

	return request, nil
}

func (m *CleanRequest) ToJSON() ([]byte, error) {
	return json.Marshal(m)
}

func (m *CleanRequest) SetToken(token string) {
	m.PaginationToken = token
}
