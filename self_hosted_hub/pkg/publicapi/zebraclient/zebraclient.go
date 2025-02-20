package zebraclient

import (
	"context"

	config "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/config"
	pb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/server_farm.job"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func GetJobPayload(jobID string) (string, error) {
	conn, err := grpc.NewClient(config.ZebraEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return "", err
	}
	defer conn.Close()

	client := pb.NewJobServiceClient(conn)
	req := pb.GetAgentPayloadRequest{JobId: jobID}

	res, err := client.GetAgentPayload(context.Background(), &req)
	if err != nil {
		return "", err
	}

	return res.Payload, nil
}

func CountByState(ctx context.Context, orgId, agentType string) (*pb.CountByStateResponse, error) {
	conn, err := grpc.NewClient(config.ZebraEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	client := pb.NewJobServiceClient(conn)
	res, err := client.CountByState(ctx, &pb.CountByStateRequest{
		OrgId:     orgId,
		AgentType: agentType,
		States:    []pb.Job_State{pb.Job_ENQUEUED, pb.Job_SCHEDULED, pb.Job_STARTED},
	})

	if err != nil {
		return nil, err
	}

	return res, nil
}

type Job struct {
	ID string `json:"id"`
}

func ListQueuedJobs(ctx context.Context, orgID string, agentTypeName string) ([]Job, error) {
	conn, err := grpc.NewClient(config.ZebraEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	client := pb.NewJobServiceClient(conn)
	req := pb.ListRequest{
		OrganizationId: orgID,
		PageSize:       500,
		Order:          pb.ListRequest_BY_CREATION_TIME_DESC,
		JobStates: []pb.Job_State{
			pb.Job_PENDING,
			pb.Job_ENQUEUED,
			pb.Job_SCHEDULED,
		},
		MachineTypes: []string{agentTypeName},
	}

	res, err := client.List(ctx, &req)
	if err != nil {
		return nil, err
	}

	jobs := make([]Job, len(res.Jobs))
	for i, job := range res.Jobs {
		jobs[i] = Job{ID: job.Id}
	}

	return jobs, nil
}
