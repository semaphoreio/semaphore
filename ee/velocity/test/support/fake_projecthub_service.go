package support

import (
	"context"

	"github.com/google/uuid"
	pb "github.com/semaphoreio/semaphore/velocity/pkg/protos/projecthub"
)

type FakeProjectHubServiceServer struct {
}

func (f FakeProjectHubServiceServer) Describe(_ context.Context, request *pb.DescribeRequest) (*pb.DescribeResponse, error) {
	return &pb.DescribeResponse{
		Project: &pb.Project{
			Metadata: &pb.Project_Metadata{
				OrgId: uuid.New().String(),
			},
		},
	}, nil
}

func (f FakeProjectHubServiceServer) List(ctx context.Context, in *pb.ListRequest) (*pb.ListResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) DescribeMany(ctx context.Context, in *pb.DescribeManyRequest) (*pb.DescribeManyResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) Create(ctx context.Context, in *pb.CreateRequest) (*pb.CreateResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) Update(ctx context.Context, in *pb.UpdateRequest) (*pb.UpdateResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) Destroy(ctx context.Context, in *pb.DestroyRequest) (*pb.DestroyResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) Users(ctx context.Context, in *pb.UsersRequest) (*pb.UsersResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) CheckDeployKey(ctx context.Context, in *pb.CheckDeployKeyRequest) (*pb.CheckDeployKeyResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) RegenerateDeployKey(ctx context.Context, in *pb.RegenerateDeployKeyRequest) (*pb.RegenerateDeployKeyResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) CheckWebhook(ctx context.Context, in *pb.CheckWebhookRequest) (*pb.CheckWebhookResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) RegenerateWebhook(ctx context.Context, in *pb.RegenerateWebhookRequest) (*pb.RegenerateWebhookResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) ChangeProjectOwner(ctx context.Context, in *pb.ChangeProjectOwnerRequest) (*pb.ChangeProjectOwnerResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) ForkAndCreate(ctx context.Context, in *pb.ForkAndCreateRequest) (*pb.ForkAndCreateResponse, error) {
	panic("implement me")

}
func (f FakeProjectHubServiceServer) GithubAppSwitch(ctx context.Context, in *pb.GithubAppSwitchRequest) (*pb.GithubAppSwitchResponse, error) {
	panic("implement me")

}

func (f FakeProjectHubServiceServer) FinishOnboarding(ctx context.Context, in *pb.FinishOnboardingRequest) (*pb.FinishOnboardingResponse, error) {
	panic("implement me")
}

func (f FakeProjectHubServiceServer) ListKeyset(ctx context.Context, in *pb.ListKeysetRequest) (*pb.ListKeysetResponse, error) {
	panic("implement me")
}

func (f FakeProjectHubServiceServer) RegenerateWebhookSecret(ctx context.Context, in *pb.RegenerateWebhookSecretRequest) (*pb.RegenerateWebhookSecretResponse, error) {
	panic("implement me")
}

func (f FakeProjectHubServiceServer) Restore(ctx context.Context, in *pb.RestoreRequest) (*pb.RestoreResponse, error) {
	panic("implement me")
}
