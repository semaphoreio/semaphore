package shared

import (
	"fmt"
	"math"
)

// IntToInt32 safely converts an int to int32 ensuring the value is within bounds.
func IntToInt32(value int, fieldName string) (int32, error) {
	if value > int(math.MaxInt32) || value < int(math.MinInt32) {
		return 0, fmt.Errorf("%s must be between %d and %d", fieldName, math.MinInt32, math.MaxInt32)
	}
	return int32(value), nil
}
