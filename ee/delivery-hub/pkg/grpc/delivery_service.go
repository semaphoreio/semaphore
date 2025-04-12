package grpc

import (
	"context"
	"errors"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/crypto"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	uuid "github.com/google/uuid"
	log "github.com/sirupsen/logrus"
)

type DeliveryService struct {
	encryptor encryptor.Encryptor
}

func NewDeliveryService(encryptor encryptor.Encryptor) *DeliveryService {
	return &DeliveryService{
		encryptor: encryptor,
	}
}

func (s *DeliveryService) CreateCanvas(ctx context.Context, request *pb.CreateCanvasRequest) (*pb.CreateCanvasResponse, error) {
	log.Infof("CreateCanvas: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for CreateCanvas: %v", request, err)
		return nil, err
	}

	canvas, err := models.CreateCanvas(orgID, request.Name)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Error(codes.InvalidArgument, err.Error())
		}

		log.Errorf("Error creating canvas on %v for CreateCanvas: %v", request, err)
		return nil, err
	}

	response := &pb.CreateCanvasResponse{
		Canvas: &pb.Canvas{
			Id:             canvas.ID.String(),
			Name:           canvas.Name,
			OrganizationId: canvas.OrganizationID.String(),
			CreatedAt:      timestamppb.New(*canvas.CreatedAt),
		},
	}

	return response, nil
}

func (s *DeliveryService) CreateEventSource(ctx context.Context, request *pb.CreateEventSourceRequest) (*pb.CreateEventSourceResponse, error) {
	log.Infof("CreateEventSource: %v", request)

	orgID, err := uuid.Parse(request.OrganizationId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid organization ID")
	}

	canvasID, err := uuid.Parse(request.CanvasId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid canvas ID")
	}

	_, err = models.FindCanvasByID(canvasID, orgID)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	key, err := s.genNewEventSourceKey(ctx, request.Name)
	if err != nil {
		log.Errorf("Error generating new event source key - org=%s canvas=%s name=%s: %v", orgID, canvasID, request.Name, err)
		return nil, status.Errorf(codes.Internal, "error generating key")
	}

	eventSource, err := models.CreateEventSource(request.Name, orgID, canvasID, key)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Errorf(codes.InvalidArgument, err.Error())
		}

		log.Errorf("Error creating for event source for org=%s canvas=%s: %v", orgID, canvasID, err)
		return nil, err
	}

	response := &pb.CreateEventSourceResponse{
		EventSource: &pb.EventSource{
			Id:             eventSource.ID.String(),
			Name:           eventSource.Name,
			OrganizationId: eventSource.OrganizationID.String(),
			CanvasId:       eventSource.CanvasID.String(),
			CreatedAt:      timestamppb.New(*eventSource.CreatedAt),
		},
		Key: string(eventSource.Key),
	}

	return response, nil
}

func (s *DeliveryService) genNewEventSourceKey(ctx context.Context, name string) ([]byte, error) {
	key, _ := crypto.Base64String(32)
	encrypted, err := s.encryptor.Encrypt(ctx, []byte(key), []byte(name))
	if err != nil {
		return nil, err
	}

	return encrypted, nil
}
