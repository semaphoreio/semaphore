package grpc

import (
	"context"
	"errors"
	"fmt"
	"sort"

	"github.com/semaphoreio/semaphore/delivery-hub/pkg/crypto"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/encryptor"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/logging"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/models"
	pb "github.com/semaphoreio/semaphore/delivery-hub/pkg/protos/delivery"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"
	"gorm.io/gorm"

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

func (s *DeliveryService) CreateCanvas(ctx context.Context, req *pb.CreateCanvasRequest) (*pb.CreateCanvasResponse, error) {
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		log.Errorf("Error reading organization id on %v for CreateCanvas: %v", req, err)
		return nil, err
	}

	canvas, err := models.CreateCanvas(orgID, req.Name)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Error(codes.InvalidArgument, err.Error())
		}

		log.Errorf("Error creating canvas on %v for CreateCanvas: %v", req, err)
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

func (s *DeliveryService) DescribeCanvas(ctx context.Context, req *pb.DescribeCanvasRequest) (*pb.DescribeCanvasResponse, error) {
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid organization ID")
	}

	canvasID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid canvas ID")
	}

	canvas, err := models.FindCanvasByID(canvasID, orgID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "canvas not found")
		}

		log.Errorf("Error describing canvas %s for organization %s: %v", canvasID, orgID, err)
		return nil, err
	}

	sources, err := models.ListEventSourcesByCanvasID(canvasID, orgID)
	if err != nil {
		log.Errorf("Error listing sources for canvas %s for organization %s: %v", canvasID, orgID, err)
		return nil, err
	}

	stages, err := models.ListStagesByCanvasID(orgID, canvasID)
	if err != nil {
		log.Errorf("Error listing stages for canvas %s for organization %s: %v", canvasID, orgID, err)
		return nil, err
	}

	serializedStages, err := serializeStages(stages, sources)
	if err != nil {
		return nil, err
	}

	response := &pb.DescribeCanvasResponse{
		Canvas: &pb.Canvas{
			Id:             canvas.ID.String(),
			Name:           canvas.Name,
			OrganizationId: canvas.OrganizationID.String(),
			CreatedAt:      timestamppb.New(*canvas.CreatedAt),
			EventSources:   serializeEventSources(sources),
			Stages:         serializedStages,
		},
	}

	return response, nil
}

func (s *DeliveryService) CreateEventSource(ctx context.Context, req *pb.CreateEventSourceRequest) (*pb.CreateEventSourceResponse, error) {
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid organization ID")
	}

	canvasID, err := uuid.Parse(req.CanvasId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid canvas ID")
	}

	canvas, err := models.FindCanvasByID(canvasID, orgID)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	plainKey, encryptedKey, err := s.genNewEventSourceKey(ctx, req.Name)
	if err != nil {
		log.Errorf("Error generating key - org=%s canvas=%s name=%s: %v", orgID, canvasID, req.Name, err)
		return nil, status.Errorf(codes.Internal, "error generating key")
	}

	eventSource, err := canvas.CreateEventSource(req.Name, encryptedKey)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Errorf(codes.InvalidArgument, err.Error())
		}

		log.Errorf("Error creating for event source for org=%s canvas=%s: %v", orgID, canvasID, err)
		return nil, err
	}

	response := &pb.CreateEventSourceResponse{
		EventSource: serializeEventSource(*eventSource),
		Key:         string(plainKey),
	}

	return response, nil
}

func (s *DeliveryService) CreateStage(ctx context.Context, req *pb.CreateStageRequest) (*pb.CreateStageResponse, error) {
	orgID, err := uuid.Parse(req.OrganizationId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid organization ID")
	}

	canvasID, err := uuid.Parse(req.CanvasId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid canvas ID")
	}

	requesterID, err := uuid.Parse(req.RequesterId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid requester ID")
	}

	canvas, err := models.FindCanvasByID(canvasID, orgID)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	template, err := validateRunTemplate(req.RunTemplate)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, err.Error())
	}

	connections, err := validateConnections(orgID, canvasID, req.Connections)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, err.Error())
	}

	err = canvas.CreateStage(req.Name, requesterID, req.ApprovalRequired, *template, connections)
	if err != nil {
		if errors.Is(err, models.ErrNameAlreadyUsed) {
			return nil, status.Errorf(codes.InvalidArgument, err.Error())
		}

		return nil, err
	}

	stage, err := models.FindStageByName(orgID, canvasID, req.Name)
	if err != nil {
		return nil, err
	}

	serialized, err := serializeStage(*stage, req.Connections)
	if err != nil {
		return nil, err
	}

	response := &pb.CreateStageResponse{
		Stage: serialized,
	}

	return response, nil
}

func (s *DeliveryService) UpdateStage(ctx context.Context, req *pb.UpdateStageRequest) (*pb.UpdateStageResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method UpdateStage not implemented")
}

func (s *DeliveryService) ApproveStageEvent(ctx context.Context, req *pb.ApproveStageEventRequest) (*pb.ApproveStageEventResponse, error) {
	stageID, err := uuid.Parse(req.StageId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid stage ID")
	}

	eventID, err := uuid.Parse(req.EventId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid event ID")
	}

	requesterID, err := uuid.Parse(req.RequesterId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid requester ID")
	}

	stage, err := models.FindStageByID(stageID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "stage not found")
		}

		return nil, err
	}

	event, err := models.FindStageEventByID(eventID, stageID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Errorf(codes.InvalidArgument, "event not found")
		}

		return nil, err
	}

	err = event.Approve(requesterID)
	if err != nil {
		return nil, err
	}

	logging.ForStage(stage).Infof("event %s approved", event.ID)

	return &pb.ApproveStageEventResponse{}, nil
}

func (s *DeliveryService) ListStageEvents(ctx context.Context, req *pb.ListStageEventsRequest) (*pb.ListStageEventsResponse, error) {
	stageID, err := uuid.Parse(req.StageId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid stage ID")
	}

	stage, err := models.FindStageByID(stageID)
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

func (s *DeliveryService) genNewEventSourceKey(ctx context.Context, name string) (string, []byte, error) {
	plainKey, _ := crypto.Base64String(32)
	encrypted, err := s.encryptor.Encrypt(ctx, []byte(plainKey), []byte(name))
	if err != nil {
		return "", nil, err
	}

	return plainKey, encrypted, nil
}

func validateRunTemplate(in *pb.RunTemplate) (*models.RunTemplate, error) {
	if in == nil {
		return nil, fmt.Errorf("missing run template")
	}

	switch in.Type {
	case pb.RunTemplate_TYPE_SEMAPHORE_WORKFLOW:
		return &models.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String(),
			SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
				Project:      in.SemaphoreWorkflow.ProjectId,
				Branch:       in.SemaphoreWorkflow.Branch,
				PipelineFile: in.SemaphoreWorkflow.PipelineFile,
			},
		}, nil

	case pb.RunTemplate_TYPE_SEMAPHORE_TASK:
		return &models.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_TASK.String(),
			SemaphoreTask: &models.SemaphoreTaskTemplate{
				Project:    in.SemaphoreTask.ProjectId,
				Task:       in.SemaphoreTask.TaskId,
				Parameters: in.SemaphoreTask.Parameters,
			},
		}, nil

	default:
		return nil, errors.New("invalid run template type")
	}
}

func serializeEventSources(eventSources []models.EventSource) []*pb.EventSource {
	sources := []*pb.EventSource{}
	for _, source := range eventSources {
		sources = append(sources, serializeEventSource(source))
	}

	return sources
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

func serializeStages(stages []models.Stage, sources []models.EventSource) ([]*pb.Stage, error) {
	s := []*pb.Stage{}
	for _, stage := range stages {
		connections, err := models.ListConnectionsForStage(stage.ID)
		if err != nil {
			return nil, err
		}

		serialized, err := convertConnections(stages, sources, connections)
		if err != nil {
			return nil, err
		}

		stage, err := serializeStage(stage, serialized)
		if err != nil {
			return nil, err
		}

		s = append(s, stage)
	}

	return s, nil
}

func serializeStage(stage models.Stage, connections []*pb.Connection) (*pb.Stage, error) {
	runTemplate, err := serializeRunTemplate(stage.RunTemplate.Data())
	if err != nil {
		return nil, err
	}

	return &pb.Stage{
		Id:               stage.ID.String(),
		Name:             stage.Name,
		OrganizationId:   stage.OrganizationID.String(),
		CanvasId:         stage.CanvasID.String(),
		CreatedAt:        timestamppb.New(*stage.CreatedAt),
		Connections:      connections,
		RunTemplate:      runTemplate,
		ApprovalRequired: stage.ApprovalRequired,
	}, nil
}

func serializeRunTemplate(runTemplate models.RunTemplate) (*pb.RunTemplate, error) {
	switch runTemplate.Type {
	case pb.RunTemplate_TYPE_SEMAPHORE_WORKFLOW.String():
		return &pb.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_WORKFLOW,
			SemaphoreWorkflow: &pb.WorkflowTemplate{
				ProjectId:    runTemplate.SemaphoreWorkflow.Project,
				Branch:       runTemplate.SemaphoreWorkflow.Branch,
				PipelineFile: runTemplate.SemaphoreWorkflow.PipelineFile,
			},
		}, nil

	case pb.RunTemplate_TYPE_SEMAPHORE_TASK.String():
		return &pb.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_TASK,
			SemaphoreTask: &pb.TaskTemplate{
				ProjectId:  runTemplate.SemaphoreTask.Project,
				TaskId:     runTemplate.SemaphoreTask.Task,
				Parameters: runTemplate.SemaphoreTask.Parameters,
			},
		}, nil

	default:
		return nil, fmt.Errorf("invalid run template type: %s", runTemplate.Type)
	}
}

func validateConnections(orgID, canvasID uuid.UUID, connections []*pb.Connection) ([]models.StageConnection, error) {
	cs := []models.StageConnection{}

	for _, connection := range connections {
		sourceID, err := findConnectionSourceID(orgID, canvasID, connection)
		if err != nil {
			return nil, fmt.Errorf("invalid connection: %v", err)
		}

		cs = append(cs, models.StageConnection{
			SourceID:   *sourceID,
			SourceType: protoToConnectionType(connection.Type),
		})
	}

	return cs, nil
}

func convertConnections(stages []models.Stage, sources []models.EventSource, in []models.StageConnection) ([]*pb.Connection, error) {
	connections := []*pb.Connection{}

	for _, c := range in {
		name, err := findConnectionName(stages, sources, c)
		if err != nil {
			return nil, fmt.Errorf("invalid connection: %v", err)
		}

		connections = append(connections, &pb.Connection{
			Type: connectionTypeToProto(c.SourceType),
			Name: name,
		})
	}

	//
	// Sort them by name so we have some predictability here.
	//
	sort.SliceStable(connections, func(i, j int) bool {
		return connections[i].Name < connections[j].Name
	})

	return connections, nil
}

func findConnectionName(stages []models.Stage, sources []models.EventSource, connection models.StageConnection) (string, error) {
	switch connection.SourceType {
	case models.SourceTypeStage:
		for _, stage := range stages {
			if stage.ID == connection.SourceID {
				return stage.Name, nil
			}
		}

		return "", fmt.Errorf("stage %s not found", connection.SourceID)

	case models.SourceTypeEventSource:
		for _, s := range sources {
			if s.ID == connection.SourceID {
				return s.Name, nil
			}
		}

		return "", fmt.Errorf("event source %s not found", connection.ID)

	default:
		return "", errors.New("invalid type")
	}
}

func findConnectionSourceID(orgID, canvasID uuid.UUID, connection *pb.Connection) (*uuid.UUID, error) {
	switch connection.Type {
	case pb.Connection_TYPE_STAGE:
		stage, err := models.FindStageByName(orgID, canvasID, connection.Name)
		if err != nil {
			return nil, fmt.Errorf("stage %s not found", connection.Name)
		}

		return &stage.ID, nil

	case pb.Connection_TYPE_EVENT_SOURCE:
		eventSource, err := models.FindEventSourceByName(orgID, canvasID, connection.Name)
		if err != nil {
			return nil, fmt.Errorf("event source %s not found", connection.Name)
		}

		return &eventSource.ID, nil

	default:
		return nil, errors.New("invalid type")
	}
}

func connectionTypeToProto(t string) pb.Connection_Type {
	switch t {
	case models.SourceTypeStage:
		return pb.Connection_TYPE_STAGE
	case models.SourceTypeEventSource:
		return pb.Connection_TYPE_EVENT_SOURCE
	default:
		return pb.Connection_TYPE_UNKNOWN
	}
}

func protoToConnectionType(t pb.Connection_Type) string {
	switch t {
	case pb.Connection_TYPE_STAGE:
		return models.SourceTypeStage
	case pb.Connection_TYPE_EVENT_SOURCE:
		return models.SourceTypeEventSource
	default:
		return ""
	}
}
