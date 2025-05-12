package models

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"time"

	expr "github.com/expr-lang/expr"
	"github.com/expr-lang/expr/ast"
	"github.com/expr-lang/expr/checker"
	"github.com/expr-lang/expr/compiler"
	"github.com/expr-lang/expr/conf"
	"github.com/expr-lang/expr/file"
	"github.com/expr-lang/expr/optimizer"
	"github.com/expr-lang/expr/vm"
	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

const (
	EventStatePending   = "pending"
	EventStateDiscarded = "discarded"
	EventStateProcessed = "processed"

	SourceTypeEventSource = "event-source"
	SourceTypeStage       = "stage"
)

type Event struct {
	ID         uuid.UUID `gorm:"primary_key;default:uuid_generate_v4()"`
	SourceID   uuid.UUID
	SourceName string
	SourceType string
	State      string
	ReceivedAt *time.Time
	Raw        datatypes.JSON
	Headers    datatypes.JSON
}

type lowercaseVisitor struct{}

func (v *lowercaseVisitor) Visit(node *ast.Node) {
	if ident, ok := (*node).(*ast.IdentifierNode); ok {
		ident.Value = strings.ToLower(ident.Value)
	}
}

func (e *Event) Discard() error {
	return database.Conn().Model(e).
		Update("state", EventStateDiscarded).
		Error
}

func (e *Event) MarkAsProcessed() error {
	return e.MarkAsProcessedInTransaction(database.Conn())
}

func (e *Event) MarkAsProcessedInTransaction(tx *gorm.DB) error {
	return tx.Model(e).
		Update("state", EventStateProcessed).
		Error
}

func (e *Event) GetData() (map[string]any, error) {
	var obj map[string]any
	err := json.Unmarshal(e.Raw, &obj)
	if err != nil {
		return nil, err
	}

	return obj, nil
}

func (e *Event) GetHeaders() (map[string]any, error) {
	var obj map[string]any
	err := json.Unmarshal(e.Headers, &obj)
	if err != nil {
		return nil, err
	}

	return obj, nil
}

func (e *Event) EvaluateBoolExpression(expression string, filterType string) (bool, error) {
	//
	// We don't want the expression to run for more than 5 seconds.
	//
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	//
	// Build our variable map.
	//
	variables, err := parseExpressionVariables(e, ctx, filterType)
	if err != nil {
		return false, fmt.Errorf("error parsing expression variables: %v", err)
	}

	//
	// Compile and run our expression.
	//
	caseSensitive := filterType != FilterTypeHeader
	program, err := CompileBooleanExpression(variables, expression, caseSensitive)

	if err != nil {
		return false, fmt.Errorf("error compiling expression: %v", err)
	}

	output, err := expr.Run(program, variables)
	if err != nil {
		return false, fmt.Errorf("error running expression: %v", err)
	}

	//
	// Output of the expression must be a boolean.
	//
	v, ok := output.(bool)
	if !ok {
		return false, fmt.Errorf("expression does not return a boolean")
	}

	return v, nil
}

func (e *Event) EvaluateStringExpression(expression string) (string, error) {
	//
	// We don't want the expression to run for more than 5 seconds.
	//
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	//
	// Build our variable map.
	//
	variables := map[string]interface{}{
		"ctx": ctx,
	}

	data, err := e.GetData()
	if err != nil {
		return "", err
	}

	for key, value := range data {
		variables[key] = value
	}

	//
	// Compile and run our expression.
	//
	program, err := expr.Compile(expression,
		expr.Env(variables),
		expr.AsKind(reflect.String),
		expr.WithContext("ctx"),
		expr.Timezone(time.UTC.String()),
	)

	if err != nil {
		return "", fmt.Errorf("error compiling expression: %v", err)
	}

	output, err := expr.Run(program, variables)
	if err != nil {
		return "", fmt.Errorf("error running expression: %v", err)
	}

	//
	// Output of the expression must be a string.
	//
	v, ok := output.(string)
	if !ok {
		return "", fmt.Errorf("expression does not return a string")
	}

	return v, nil
}

func CreateEvent(sourceID uuid.UUID, sourceName, sourceType string, raw []byte, headers []byte) (*Event, error) {
	return CreateEventInTransaction(database.Conn(), sourceID, sourceName, sourceType, raw, headers)
}

func CreateEventInTransaction(tx *gorm.DB, sourceID uuid.UUID, sourceName, sourceType string, raw []byte, headers []byte) (*Event, error) {
	now := time.Now()

	event := Event{
		SourceID:   sourceID,
		SourceName: sourceName,
		SourceType: sourceType,
		State:      EventStatePending,
		ReceivedAt: &now,
		Raw:        datatypes.JSON(raw),
		Headers:    datatypes.JSON(headers),
	}

	err := tx.
		Clauses(clause.Returning{}).
		Create(&event).
		Error

	if err != nil {
		return nil, err
	}

	return &event, nil
}

func ListEventsBySourceID(sourceID uuid.UUID) ([]Event, error) {
	var events []Event
	return events, database.Conn().Where("source_id = ?", sourceID).Find(&events).Error
}

func ListPendingEvents() ([]Event, error) {
	var events []Event
	return events, database.Conn().Where("state = ?", EventStatePending).Find(&events).Error
}

func FindEventByID(id uuid.UUID) (*Event, error) {
	var event Event
	return &event, database.Conn().Where("id = ?", id).First(&event).Error
}

func FindLastEventBySourceID(sourceID uuid.UUID) (map[string]any, error) {
	var event Event
	err := database.Conn().
		Table("events").
		Select("raw").
		Where("source_id = ?", sourceID).
		Order("received_at DESC").
		First(&event).
		Error

	if err != nil {
		return nil, fmt.Errorf("error finding event: %v", err)
	}

	var m map[string]any
	err = json.Unmarshal(event.Raw, &m)
	if err != nil {
		return nil, fmt.Errorf("error unmarshaling data: %v", err)
	}

	return m, nil
}

// CompileBooleanExpression compiles a boolean expression.
// The code below is a copy of the expr.Compile function, but with
// some changes to make it case insensitive for headers:
// https://github.com/expr-lang/expr/blob/master/compiler/compiler.go#L24
//
// variables: the variables to be used in the expression.
// expression: the expression to be compiled.
// caseSensitive: whether the expression should be case sensitive.
func CompileBooleanExpression(variables map[string]any, expression string, caseSensitive bool) (*vm.Program, error) {
	config := conf.CreateNew()
	options := []expr.Option{
		expr.Env(variables),
		expr.AsBool(),
		expr.WithContext("ctx"),
		expr.Timezone(time.UTC.String()),
	}

	for _, op := range options {
		op(config)
	}
	for name := range config.Disabled {
		delete(config.Builtins, name)
	}
	config.Check()

	tree, err := checker.ParseCheck(expression, config)

	if err != nil {
		return nil, fmt.Errorf("error parsing expression: %v", err)
	}

	if !caseSensitive {
		ast.Walk(&tree.Node, &lowercaseVisitor{})
	}

	if config.Optimize {
		err = optimizer.Optimize(&tree.Node, config)
		if err != nil {
			var fileError *file.Error
			if errors.As(err, &fileError) {
				return nil, fileError.Bind(tree.Source)
			}
			return nil, err
		}
	}

	for _, option := range options {
		option(config)
	}

	return compiler.Compile(tree, config)
}

func parseExpressionVariables(e *Event, ctx context.Context, filterType string) (map[string]interface{}, error) {
	variables := map[string]interface{}{
		"ctx": ctx,
	}

	if filterType == FilterTypeData {
		var content map[string]any
		var err error

		switch filterType {
		case FilterTypeData:
			content, err = e.GetData()
			if err != nil {
				return nil, err
			}

		case FilterTypeHeader:
			content, err = e.GetHeaders()
			if err != nil {
				return nil, err
			}
		default:
			return nil, fmt.Errorf("invalid filter type: %s", filterType)
		}

		for key, value := range content {
			if filterType == FilterTypeHeader {
				key = strings.ToLower(key)
			}

			variables[key] = value
		}
	}

	return variables, nil
}
