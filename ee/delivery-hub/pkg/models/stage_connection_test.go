package models

import (
	"testing"

	"github.com/stretchr/testify/require"
	"gorm.io/datatypes"
)

func Test__StageConnectionFilter(t *testing.T) {
	t.Run("single expression filter -> true", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a == 1 && b == 2`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
							{Name: "b", Path: "b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 2}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.True(t, accept)
	})

	t.Run("single expression filter -> false", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a == 1 && b == 2`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
							{Name: "b", Path: "b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 3}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.False(t, accept)
	})

	t.Run("expression filter with dot syntax -> true", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a.b == 2 && b == 2`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
							{Name: "b", Path: "a.b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": {"b": 2}}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.True(t, accept)
	})

	t.Run("expression filter with array syntax for array -> true", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `1 in a`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": [1, 2, 3]}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.True(t, accept)
	})

	t.Run("expression filter with improper dot syntax -> error", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a.b == 2 && b == 2`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
							{Name: "b", Path: "a.b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 2}`)}
		_, err := conn.Accept(event)
		require.ErrorContains(t, err, "key 'a' is not a map")
	})

	t.Run("single expression filter with missing variable -> error", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a == 1 && b == 2`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 3}`)}
		_, err := conn.Accept(event)
		require.ErrorContains(t, err, "unknown name b")
	})

	t.Run("multiple expression filters with AND", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorAnd,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a == 1`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
						},
					},
				},
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `b == 3`,
						Variables: []ExpressionVariable{
							{Name: "b", Path: "b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 2}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.False(t, accept)
	})

	t.Run("multiple expression filters with OR", func(t *testing.T) {
		conn := StageConnection{
			FilterOperator: FilterOperatorOr,
			Filters: datatypes.NewJSONSlice([]StageConnectionFilter{
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `a == 1`,
						Variables: []ExpressionVariable{
							{Name: "a", Path: "a"},
						},
					},
				},
				{
					Type: FilterTypeExpression,
					Expression: &ExpressionFilter{
						Expression: `b == 3`,
						Variables: []ExpressionVariable{
							{Name: "b", Path: "b"},
						},
					},
				},
			}),
		}

		event := &Event{Raw: []byte(`{"a": 1, "b": 2}`)}
		accept, err := conn.Accept(event)
		require.NoError(t, err)
		require.True(t, accept)
	})
}
