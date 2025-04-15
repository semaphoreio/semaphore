package events

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"
)

func Test__GetNestedField(t *testing.T) {
	type testCase struct {
		name           string
		input          []byte
		path           []string
		expectedError  error
		expectedOutput any
	}

	testCases := []testCase{
		{
			name:           "key exists and is an integer",
			input:          []byte(`{"a": 1}`),
			path:           []string{"a"},
			expectedError:  nil,
			expectedOutput: 1,
		},
		{
			name:           "key exists and is a string",
			input:          []byte(`{"a": "my-value-1"}`),
			path:           []string{"a"},
			expectedError:  nil,
			expectedOutput: "my-value-1",
		},
		{
			name:           "key exists and is an empty array",
			input:          []byte(`{"a": []}`),
			path:           []string{"a"},
			expectedError:  nil,
			expectedOutput: []any{},
		},
		{
			name:           "key exists and is an integer array",
			input:          []byte(`{"a": [1, 2, 3]}`),
			path:           []string{"a"},
			expectedError:  nil,
			expectedOutput: []any{float64(1), float64(2), float64(3)},
		},
		{
			name:           "two levels, key exists",
			input:          []byte(`{"a": {"b": 1}}`),
			path:           []string{"a", "b"},
			expectedError:  nil,
			expectedOutput: 1,
		},
		{
			name:           "two levels, key does not exist",
			input:          []byte(`{"a": {"b": 1}}`),
			path:           []string{"a", "c"},
			expectedError:  fmt.Errorf("key 'c' not found"),
			expectedOutput: nil,
		},
		{
			name:           "two levels, key is not a map",
			input:          []byte(`{"a": {"b": 1}}`),
			path:           []string{"a", "b", "c"},
			expectedError:  fmt.Errorf("key 'b' is not a map"),
			expectedOutput: nil,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var m map[string]any
			err := json.Unmarshal(tc.input, &m)
			require.NoError(t, err)
			output, err := GetNestedField(m, tc.path)
			require.Equal(t, tc.expectedError, err)
			require.EqualValues(t, tc.expectedOutput, output)
		})
	}
}
