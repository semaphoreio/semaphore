package testsupport

import (
	"context"

	ia_response_status "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/response_status"
	ia_user "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/user"
)

const FakeUserServiceUserID string = "6a0f8cbdd78feb0e9a3b579976948060411ad9f6"

type FakeUserService struct {
	ia_user.UnimplementedUserServiceServer
}

func (*FakeUserService) Describe(ctx context.Context, in *ia_user.DescribeRequest) (*ia_user.DescribeResponse, error) {
	return &ia_user.DescribeResponse{
		Name:  "Semaphore VCR Tester from Repohub",
		Email: "mkutryj+devops@renderedtext.com",
		Status: &ia_response_status.ResponseStatus{
			Code:    ia_response_status.ResponseStatus_OK,
			Message: "",
		},
	}, nil
}
