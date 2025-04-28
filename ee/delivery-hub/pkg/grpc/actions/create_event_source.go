package actions

import (
	"context"
	"errors"
	"fmt"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/crypto"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/grpc/actions/messages"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
)

func CreateEventSource(ctx context.Context, encryptor encryptor.Encryptor, req *pb.CreateEventSourceRequest) (*pb.CreateEventSourceResponse, error) {
	err := ValidateUUIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	canvas, err := models.FindCanvasByID(req.CanvasId, req.OrganizationId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	logger := logging.ForCanvas(canvas)
	plainKey, encryptedKey, err := genNewEventSourceKey(ctx, encryptor, req.Name)
	if err != nil {
		logger.Errorf("Error generating event source key. Request: %v. Error: %v", req, err)
		return nil, status.Errorf(codes.Internal, "error generating key")
	}

	eventSource, err := canvas.CreateEventSource(req.Name, encryptedKey)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Errorf(codes.InvalidArgument, err.Error())
		}

		log.Errorf("Error creating event source. Request: %v. Error: %v", req, err)
		return nil, err
	}

	response := &pb.CreateEventSourceResponse{
		EventSource: serializeEventSource(*eventSource),
		Key:         string(plainKey),
	}

	logger.Infof("Created event source. Request: %v", req)

	err = messages.NewEventSourceCreatedMessage(eventSource).Publish()

	if err != nil {
		return nil, fmt.Errorf("error sending AMQP message: %v", err)
	}

	return response, nil
}

func serializeEventSource(eventSource models.EventSource) *pb.EventSource {
	return &pb.EventSource{
		Id:             eventSource.ID.String(),
		Name:           eventSource.Name,
		OrganizationId: eventSource.OrganizationID.String(),
		CanvasId:       eventSource.CanvasID.String(),
		CreatedAt:      timestamppb.New(*eventSource.CreatedAt),
	}
}

func genNewEventSourceKey(ctx context.Context, encryptor encryptor.Encryptor, name string) (string, []byte, error) {
	plainKey, _ := crypto.Base64String(32)
	encrypted, err := encryptor.Encrypt(ctx, []byte(plainKey), []byte(name))
	if err != nil {
		return "", nil, err
	}

	return plainKey, encrypted, nil
}
