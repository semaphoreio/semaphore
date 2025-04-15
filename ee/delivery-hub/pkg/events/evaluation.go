package events

import "fmt"

// TODO: support array traversing
func GetNestedField(obj map[string]any, path []string) (any, error) {
	first := path[0]
	v, ok := obj[first]
	if !ok {
		return nil, fmt.Errorf("key '%s' not found", first)
	}

	//
	// We have reached the end of the recursion, just return the value.
	//
	if len(path) == 1 {
		return v, nil
	}

	//
	// If the current value is not a map, and we still have more path to traverse,
	// this is not a valid path. We should stop and fail here.
	//
	m, ok := v.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("key '%s' is not a map", first)
	}

	//
	// Otherwise, continue traversing.
	//
	return GetNestedField(m, path[1:])
}
