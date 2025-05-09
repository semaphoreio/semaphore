package actions

import (
	"context"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func UpdateTagState(ctx context.Context, req *pb.UpdateTagStateRequest) (*pb.UpdateTagStateResponse, error) {
	if req.Tag == nil {
		return nil, status.Errorf(codes.InvalidArgument, "missing tag")
	}

	if req.Tag.Name == "" || req.Tag.Value == "" {
		return nil, status.Errorf(codes.InvalidArgument, "missing tag name or value")
	}

	err := models.UpdateTagState(req.Tag.Name, req.Tag.Value, tagStateFromProto(req.Tag.State))
	if err != nil {
		log.Errorf("Error updating tag state for %v: %v", req, err)
		return nil, status.Errorf(codes.Internal, err.Error())
	}

	return &pb.UpdateTagStateResponse{}, nil
}

func tagStateFromProto(state pb.Tag_State) string {
	switch state {
	case pb.Tag_TAG_STATE_HEALTHY:
		return models.TagStateHealthy
	case pb.Tag_TAG_STATE_UNHEALTHY:
		return models.TagStateUnhealthy
	default:
		return models.TagStateUnknown
	}
}

func tagStateToProto(state string) pb.Tag_State {
	switch state {
	case models.TagStateHealthy:
		return pb.Tag_TAG_STATE_HEALTHY
	case models.TagStateUnhealthy:
		return pb.Tag_TAG_STATE_UNHEALTHY
	default:
		return pb.Tag_TAG_STATE_UNKNOWN
	}
}
