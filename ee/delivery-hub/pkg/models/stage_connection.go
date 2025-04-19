package models

import (
	"context"
	"fmt"
	"time"

	"github.com/expr-lang/expr"
	uuid "github.com/google/uuid"
	"github.com/semaphoreio/semaphore/delivery-hub/pkg/database"
	"gorm.io/datatypes"
)

const (
	FilterTypeData    = "data"
	FilterOperatorAnd = "and"
	FilterOperatorOr  = "or"
)

type StageConnection struct {
	ID             uuid.UUID `gorm:"type:uuid;default:uuid_generate_v4()"`
	StageID        uuid.UUID
	SourceID       uuid.UUID
	SourceType     string
	Filters        datatypes.JSONSlice[StageConnectionFilter]
	FilterOperator string
}

func (c *StageConnection) Accept(event *Event) (bool, error) {
	if len(c.Filters) == 0 {
		return true, nil
	}

	switch c.FilterOperator {
	case FilterOperatorOr:
		return c.any(event)

	case FilterOperatorAnd:
		return c.all(event)

	default:
		return false, fmt.Errorf("invalid filter operator: %s", c.FilterOperator)
	}
}

func (c *StageConnection) all(event *Event) (bool, error) {
	for _, filter := range c.Filters {
		ok, err := filter.Evaluate(event)
		if err != nil {
			return false, fmt.Errorf("error evaluating filter: %v", err)
		}

		if !ok {
			return false, nil
		}
	}

	return true, nil
}

func (c *StageConnection) any(event *Event) (bool, error) {
	for _, filter := range c.Filters {
		ok, err := filter.Evaluate(event)
		if err != nil {
			return false, fmt.Errorf("error evaluating filter: %v", err)
		}

		if ok {
			return true, nil
		}
	}

	return false, nil
}

type StageConnectionFilter struct {
	Type string
	Data *DataFilter
}

func (f *StageConnectionFilter) EvaluateExpression(event *Event) (bool, error) {
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

	data, err := event.GetData()
	if err != nil {
		return false, err
	}

	for key, value := range data {
		variables[key] = value
	}

	//
	// Compile and run our expression.
	//
	program, err := expr.Compile(f.Data.Expression,
		expr.Env(variables),
		expr.AsBool(),
		expr.WithContext("ctx"),
		expr.Timezone(time.UTC.String()),
	)

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

func (f *StageConnectionFilter) Evaluate(event *Event) (bool, error) {
	switch f.Type {
	case FilterTypeData:
		return f.EvaluateExpression(event)

	default:
		return false, fmt.Errorf("invalid filter type: %s", f.Type)
	}
}

type DataFilter struct {
	Expression string
}

func ListConnectionsForSource(sourceID uuid.UUID, connectionType string) ([]StageConnection, error) {
	var connections []StageConnection
	err := database.Conn().
		Where("source_id = ?", sourceID).
		Where("source_type = ?", connectionType).
		Find(&connections).
		Error

	if err != nil {
		return nil, err
	}

	return connections, nil
}

func ListConnectionsForStage(stageID uuid.UUID) ([]StageConnection, error) {
	var connections []StageConnection
	err := database.Conn().
		Where("stage_id = ?", stageID).
		Find(&connections).
		Error

	if err != nil {
		return nil, err
	}

	return connections, nil
}
