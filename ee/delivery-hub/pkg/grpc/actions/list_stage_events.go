package actions

import (
	"context"
	"errors"
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
	"gorm.io/gorm"
)

func ListStageEvents(ctx context.Context, req *pb.ListStageEventsRequest) (*pb.ListStageEventsResponse, error) {
	err := ValidateUUIDs(req.OrganizationId, req.CanvasId, req.StageId)
	if err != nil {
		return nil, err
	}

	canvas, err := models.FindCanvasByID(req.CanvasId, req.OrganizationId)
	if err != nil {
		return nil, err
	}

	stage, err := canvas.FindStageByID(req.StageId)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "stage not found")
		}

		return nil, err
	}

	states, err := validateStageEventStates(req.States)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, err.Error())
	}

	events, err := stage.ListEvents(states)
	if err != nil {
		return nil, err
	}

	response := &pb.ListStageEventsResponse{
		Events: serializeStageEvents(events),
	}

	return response, nil
}

func validateStageEventStates(in []pb.StageEvent_State) ([]string, error) {
	//
	// If no states are provided, return all states.
	//
	if len(in) == 0 {
		return []string{
			models.StageEventPending,
			models.StageEventWaitingForApproval,
			models.StageEventProcessed,
		}, nil
	}

	states := []string{}
	for _, s := range in {
		state, err := protoToState(s)
		if err != nil {
			return nil, err
		}

		states = append(states, state)
	}

	return states, nil
}

func protoToState(state pb.StageEvent_State) (string, error) {
	switch state {
	case pb.StageEvent_PENDING:
		return models.StageEventPending, nil
	case pb.StageEvent_WAITING_FOR_APPROVAL:
		return models.StageEventWaitingForApproval, nil
	case pb.StageEvent_PROCESSED:
		return models.StageEventProcessed, nil
	default:
		return "", fmt.Errorf("invalid state: %v", state)
	}
}

func serializeStageEvents(in []models.StageEvent) []*pb.StageEvent {
	out := []*pb.StageEvent{}
	for _, i := range in {
		e := &pb.StageEvent{
			Id:         i.ID.String(),
			State:      stateToProto(i.State),
			CreatedAt:  timestamppb.New(*i.CreatedAt),
			SourceId:   i.SourceID.String(),
			SourceType: pb.Connection_TYPE_EVENT_SOURCE,
		}

		if i.ApprovedAt != nil {
			e.ApprovedAt = timestamppb.New(*i.ApprovedAt)
		}

		if i.ApprovedBy != nil {
			e.ApprovedBy = i.ApprovedBy.String()
		}

		out = append(out, e)
	}

	return out
}

func stateToProto(state string) pb.StageEvent_State {
	switch state {
	case models.StageEventPending:
		return pb.StageEvent_PENDING
	case models.StageEventWaitingForApproval:
		return pb.StageEvent_WAITING_FOR_APPROVAL
	case models.StageEventProcessed:
		return pb.StageEvent_PROCESSED
	default:
		return pb.StageEvent_UNKNOWN
	}
}
