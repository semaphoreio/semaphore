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

	requesterID, err := uuid.Parse(req.RequesterId)
	if err != nil {
		log.Errorf("Error reading requester id on %v for CreateCanvas: %v", req, err)
		return nil, err
	}

	canvas, err := models.CreateCanvas(orgID, requesterID, req.Name)
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
	orgID, canvasID, err := s.validateCommonIDs(req.OrganizationId, req.Id)
	if err != nil {
		return nil, err
	}

	canvas, err := models.FindCanvasByID(*canvasID, *orgID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "canvas not found")
		}

		log.Errorf("Error describing canvas %s for organization %s: %v", canvasID, orgID, err)
		return nil, err
	}

	response := &pb.DescribeCanvasResponse{
		Canvas: &pb.Canvas{
			Id:             canvas.ID.String(),
			Name:           canvas.Name,
			OrganizationId: canvas.OrganizationID.String(),
			CreatedAt:      timestamppb.New(*canvas.CreatedAt),
			CreatedBy:      canvas.CreatedBy.String(),
		},
	}

	return response, nil
}

func (s *DeliveryService) CreateEventSource(ctx context.Context, req *pb.CreateEventSourceRequest) (*pb.CreateEventSourceResponse, error) {
	orgID, canvasID, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	canvas, err := models.FindCanvasByID(*canvasID, *orgID)
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

func (s *DeliveryService) DescribeEventSource(ctx context.Context, req *pb.DescribeEventSourceRequest) (*pb.DescribeEventSourceResponse, error) {
	orgID, canvasID, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	if req.Id == "" && req.Name == "" {
		return nil, status.Errorf(codes.InvalidArgument, "must specify one of: id or name")
	}

	source, err := s.findEventSource(*orgID, *canvasID, req)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, status.Error(codes.NotFound, "event source not found")
		}

		log.Errorf("Error describing event source in canvas %s: %v", canvasID, err)
		return nil, err
	}

	response := &pb.DescribeEventSourceResponse{
		EventSource: serializeEventSource(*source),
	}

	return response, nil
}

func (s *DeliveryService) findEventSource(orgID, canvasID uuid.UUID, req *pb.DescribeEventSourceRequest) (*models.EventSource, error) {
	if req.Name == "" {
		return models.FindEventSourceByName(orgID, canvasID, req.Name)
	}

	ID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid ID")
	}

	return models.FindEventSourceByID(&ID, &orgID, &canvasID)
}

func (s *DeliveryService) CreateStage(ctx context.Context, req *pb.CreateStageRequest) (*pb.CreateStageResponse, error) {
	orgID, canvasID, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	requesterID, err := uuid.Parse(req.RequesterId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid requester ID")
	}

	canvas, err := models.FindCanvasByID(*canvasID, *orgID)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	template, err := validateRunTemplate(req.RunTemplate)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, err.Error())
	}

	connections, err := validateConnections(*orgID, *canvasID, req.Connections)
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

	stage, err := models.FindStageByName(*orgID, *canvasID, req.Name)
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

func (s *DeliveryService) DescribeStage(ctx context.Context, req *pb.DescribeStageRequest) (*pb.DescribeStageResponse, error) {
	org, canvas, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	_, err = models.FindCanvasByID(*canvas, *org)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "canvas not found")
	}

	stage, err := s.findStage(*org, *canvas, req)
	if err != nil {
		return nil, err
	}

	//
	// TODO: we have to list all stages/sources because the API expects
	// the stage connection to use names, and the stage_connections table does not record that.
	//

	stages, err := models.ListStagesByCanvasID(*org, *canvas)
	if err != nil {
		return nil, fmt.Errorf("failed to list stages for canvas: %w", err)
	}

	sources, err := models.ListEventSourcesByCanvasID(*org, *canvas)
	if err != nil {
		return nil, fmt.Errorf("failed to list event sources for canvas: %w", err)
	}

	connections, err := models.ListConnectionsForStage(stage.ID)
	if err != nil {
		return nil, fmt.Errorf("failed to list connections for stage: %w", err)
	}

	conn, err := serializeConnections(stages, sources, connections)
	if err != nil {
		return nil, err
	}

	serialized, err := serializeStage(*stage, conn)
	if err != nil {
		return nil, err
	}

	response := &pb.DescribeStageResponse{
		Stage: serialized,
	}

	return response, nil
}

func (s *DeliveryService) findStage(orgID, canvasID uuid.UUID, req *pb.DescribeStageRequest) (*models.Stage, error) {
	if req.Name != "" {
		return models.FindStageByName(orgID, canvasID, req.Name)
	}

	ID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid ID")
	}

	return models.FindStageByID(orgID, canvasID, ID)
}

func (s *DeliveryService) UpdateStage(ctx context.Context, req *pb.UpdateStageRequest) (*pb.UpdateStageResponse, error) {
	return nil, status.Errorf(codes.Unimplemented, "method UpdateStage not implemented")
}

func (s *DeliveryService) ApproveStageEvent(ctx context.Context, req *pb.ApproveStageEventRequest) (*pb.ApproveStageEventResponse, error) {
	org, canvas, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

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

	stage, err := models.FindStageByID(*org, *canvas, stageID)
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

func (s *DeliveryService) ListEventSources(ctx context.Context, req *pb.ListEventSourcesRequest) (*pb.ListEventSourcesResponse, error) {
	org, canvas, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	sources, err := models.ListEventSourcesByCanvasID(*org, *canvas)
	if err != nil {
		return nil, err
	}

	response := &pb.ListEventSourcesResponse{
		EventSources: serializeEventSources(sources),
	}

	return response, nil
}

func (s *DeliveryService) ListStages(ctx context.Context, req *pb.ListStagesRequest) (*pb.ListStagesResponse, error) {
	org, canvas, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	stages, err := models.ListStagesByCanvasID(*org, *canvas)
	if err != nil {
		return nil, fmt.Errorf("failed to list stages for canvas: %w", err)
	}

	sources, err := models.ListEventSourcesByCanvasID(*org, *canvas)
	if err != nil {
		return nil, fmt.Errorf("failed to list event sources for canvas: %w", err)
	}

	serialized, err := serializeStages(stages, sources)
	if err != nil {
		return nil, err
	}

	response := &pb.ListStagesResponse{
		Stages: serialized,
	}

	return response, nil
}

func (s *DeliveryService) ListStageEvents(ctx context.Context, req *pb.ListStageEventsRequest) (*pb.ListStageEventsResponse, error) {
	org, canvas, err := s.validateCommonIDs(req.OrganizationId, req.CanvasId)
	if err != nil {
		return nil, err
	}

	stageID, err := uuid.Parse(req.StageId)
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid stage ID")
	}

	stage, err := models.FindStageByID(*org, *canvas, stageID)
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

func (s *DeliveryService) validateCommonIDs(orgID, canvasID string) (*uuid.UUID, *uuid.UUID, error) {
	org, err := uuid.Parse(orgID)
	if err != nil {
		return nil, nil, status.Errorf(codes.InvalidArgument, "invalid organization ID")
	}

	canvas, err := uuid.Parse(canvasID)
	if err != nil {
		return nil, nil, status.Errorf(codes.InvalidArgument, "invalid canvas ID")
	}

	return &org, &canvas, nil
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
			Type: models.RunTemplateTypeSemaphoreWorkflow,
			SemaphoreWorkflow: &models.SemaphoreWorkflowTemplate{
				ProjectID:    in.SemaphoreWorkflow.ProjectId,
				Branch:       in.SemaphoreWorkflow.Branch,
				PipelineFile: in.SemaphoreWorkflow.PipelineFile,
			},
		}, nil

	case pb.RunTemplate_TYPE_SEMAPHORE_TASK:
		return &models.RunTemplate{
			Type: models.RunTemplateTypeSemaphoreTask,
			SemaphoreTask: &models.SemaphoreTaskTemplate{
				ProjectID:    in.SemaphoreTask.ProjectId,
				TaskID:       in.SemaphoreTask.TaskId,
				Branch:       in.SemaphoreTask.Branch,
				PipelineFile: in.SemaphoreTask.PipelineFile,
				Parameters:   in.SemaphoreTask.Parameters,
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

		serialized, err := serializeConnections(stages, sources, connections)
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
	case models.RunTemplateTypeSemaphoreWorkflow:
		return &pb.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_WORKFLOW,
			SemaphoreWorkflow: &pb.WorkflowTemplate{
				ProjectId:    runTemplate.SemaphoreWorkflow.ProjectID,
				Branch:       runTemplate.SemaphoreWorkflow.Branch,
				PipelineFile: runTemplate.SemaphoreWorkflow.PipelineFile,
			},
		}, nil

	case models.RunTemplateTypeSemaphoreTask:
		return &pb.RunTemplate{
			Type: pb.RunTemplate_TYPE_SEMAPHORE_TASK,
			SemaphoreTask: &pb.TaskTemplate{
				ProjectId:    runTemplate.SemaphoreTask.ProjectID,
				TaskId:       runTemplate.SemaphoreTask.TaskID,
				Branch:       runTemplate.SemaphoreTask.Branch,
				PipelineFile: runTemplate.SemaphoreTask.PipelineFile,
				Parameters:   runTemplate.SemaphoreTask.Parameters,
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

		filters, err := validateFilters(connection.Filters)
		if err != nil {
			return nil, err
		}

		cs = append(cs, models.StageConnection{
			SourceID:       *sourceID,
			SourceType:     protoToConnectionType(connection.Type),
			FilterOperator: protoToFilterOperator(connection.FilterOperator),
			Filters:        filters,
		})
	}

	return cs, nil
}

func validateFilters(in []*pb.Connection_Filter) ([]models.StageConnectionFilter, error) {
	filters := []models.StageConnectionFilter{}
	for i, f := range in {
		filter, err := validateFilter(f)
		if err != nil {
			return nil, fmt.Errorf("invalid filter [%d]: %v", i, err)
		}

		filters = append(filters, *filter)
	}

	return filters, nil
}

func validateFilter(filter *pb.Connection_Filter) (*models.StageConnectionFilter, error) {
	switch filter.Type {
	case pb.Connection_FILTER_TYPE_EXPRESSION:
		return validateExpressionFilter(filter.Expression)
	default:
		return nil, fmt.Errorf("invalid filter type: %s", filter.Type)
	}
}

func validateExpressionFilter(filter *pb.Connection_ExpressionFilter) (*models.StageConnectionFilter, error) {
	if filter == nil {
		return nil, fmt.Errorf("no filter provided")
	}

	if filter.Expression == "" {
		return nil, fmt.Errorf("expression is empty")
	}

	variables, err := validateExpressionVariables(filter.Variables)
	if err != nil {
		return nil, fmt.Errorf("invalid variables: %v", err)
	}

	return &models.StageConnectionFilter{
		Type: models.FilterTypeExpression,
		Expression: &models.ExpressionFilter{
			Expression: filter.Expression,
			Variables:  variables,
		},
	}, nil
}

func validateExpressionVariables(in []*pb.Connection_ExpressionFilter_Variable) ([]models.ExpressionVariable, error) {
	variables := make([]models.ExpressionVariable, len(in))

	for i, v := range in {
		if v.Name == "" {
			return nil, fmt.Errorf("variable name is empty")
		}

		if v.Path == "" {
			return nil, fmt.Errorf("path for variable '%s' is empty", v.Name)
		}

		variables[i] = models.ExpressionVariable{
			Name: v.Name,
			Path: v.Path,
		}
	}

	return variables, nil
}

func protoToFilterOperator(in pb.Connection_FilterOperator) string {
	switch in {
	case pb.Connection_FILTER_OPERATOR_OR:
		return models.FilterOperatorOr
	default:
		return models.FilterOperatorAnd
	}
}

func filterOperatorToProto(in string) pb.Connection_FilterOperator {
	switch in {
	case models.FilterOperatorOr:
		return pb.Connection_FILTER_OPERATOR_OR
	default:
		return pb.Connection_FILTER_OPERATOR_AND
	}
}

func serializeFilters(in []models.StageConnectionFilter) ([]*pb.Connection_Filter, error) {
	filters := []*pb.Connection_Filter{}

	for _, f := range in {
		filter, err := serializeFilter(f)
		if err != nil {
			return nil, fmt.Errorf("invalid filter: %v", err)
		}

		filters = append(filters, filter)
	}

	return filters, nil
}

func serializeFilter(in models.StageConnectionFilter) (*pb.Connection_Filter, error) {
	switch in.Type {
	case models.FilterTypeExpression:
		vars := []*pb.Connection_ExpressionFilter_Variable{}
		for _, v := range in.Expression.Variables {
			vars = append(vars, &pb.Connection_ExpressionFilter_Variable{
				Name: v.Name,
				Path: v.Path,
			})
		}

		return &pb.Connection_Filter{
			Type: pb.Connection_FILTER_TYPE_EXPRESSION,
			Expression: &pb.Connection_ExpressionFilter{
				Expression: in.Expression.Expression,
				Variables:  vars,
			},
		}, nil
	default:
		return nil, fmt.Errorf("invalid filter type: %s", in.Type)
	}
}

func serializeConnections(stages []models.Stage, sources []models.EventSource, in []models.StageConnection) ([]*pb.Connection, error) {
	connections := []*pb.Connection{}

	for _, c := range in {
		name, err := findConnectionName(stages, sources, c)
		if err != nil {
			return nil, fmt.Errorf("invalid connection: %v", err)
		}

		filters, err := serializeFilters(c.Filters)
		if err != nil {
			return nil, fmt.Errorf("invalid filters: %v", err)
		}

		connections = append(connections, &pb.Connection{
			Type:           connectionTypeToProto(c.SourceType),
			Name:           name,
			FilterOperator: filterOperatorToProto(c.FilterOperator),
			Filters:        filters,
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
