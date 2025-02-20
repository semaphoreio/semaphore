// Package calc holds functions to calculate mathematical values.
package calc

import (
	"math"
	"sort"
	"time"
)

//excerpt from golang.org/x/exp/constraints

type Signed interface {
	int | int64 | int32 | int16 | int8
}

type Unsigned interface {
	uint | uint64 | uint32 | uint16 | uint8
}

type Integer interface {
	Signed | Unsigned
}

type Float interface {
	~float32 | ~float64
}

type Ordered interface {
	Integer | Float | ~string
}

// Duration is int64
type Number interface {
	Integer | Float | time.Duration
}

// Max returns the maximum of an array.
// Warning, array cannot be empty.
func Max[T Number](slice []T) T {
	var max T
	if len(slice) == 0 {
		return max
	}
	max = slice[0]
	for _, v := range slice {
		if v > max {
			max = v
		}
	}

	return max
}

// MaxFunc returns the maximum value for a nested property inside an array.
// Warning, array cannot be empty.
func MaxFunc[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, Max[V])
}

// Min returns the Min of an array.
// Warning, array cannot be empty.
func Min[T Number](slice []T) T {
	var min T
	if len(slice) == 0 {
		return min
	}
	min = slice[0]
	for _, v := range slice {
		if v < min {
			min = v
		}
	}

	return min
}

// MinFunc returns the minimum value for a nested property inside an array.
// Warning, array cannot be empty.
func MinFunc[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, Min[V])
}

func applyFunc[T any, V Number](slice []T, accessorFunc func(T) V, mathFunc func(slice []V) V) V {
	holder := make([]V, 0)
	for _, value := range slice {
		holder = append(holder, accessorFunc(value))
	}

	return mathFunc(holder)
}

// Problem: division looses float point when type is integer. This is a problem for Average and Median functions.
// time.Duration = int64

func Average[T Number](slice []T) T {
	var sum T
	if len(slice) == 0 {
		return sum
	}

	for _, v := range slice {
		sum += v
	}

	return sum / T(len(slice))
}

func AverageFunc[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, Average[V])
}

// Median returns the median of an array.
func Median[T Number](slice []T) T {
	var noop T
	size := len(slice)
	if size == 0 {
		return noop
	}

	sort.Slice(slice, func(i, j int) bool {
		return slice[i] < slice[j]
	})

	if size%2 == 0 {
		return (slice[(size/2)-1] + slice[(size/2)]) / 2.0
	}

	return slice[len(slice)/2]
}

func MedianFunc[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, Median[V])
}

func P95[T Number](slice []T) T {
	var noop T
	size := len(slice)
	if size == 0 {
		return noop
	}

	sort.Slice(slice, func(i, j int) bool {
		return slice[i] < slice[j]
	})

	index := math.Ceil(float64(size)*0.95) - 1
	return slice[int(index)]
}

func P95Func[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, P95[V])
}

func StdDev[T Number](slice []T) T {
	var noop T
	size := float64(len(slice))
	if len(slice) == 0 {
		return noop
	}

	var avg float64
	sum := sum(slice)

	avg = float64(sum) / size

	summation := 0.0
	for _, x := range slice {
		xi := float64(x)
		summation += (xi - avg) * (xi - avg)
	}

	variance := summation / size

	stdDev := T(math.Sqrt(variance))
	return stdDev
}

func StdDevFunc[T any, V Number](slice []T, f func(T) V) V {
	return applyFunc(slice, f, StdDev[V])
}

func sum[T Number](slice []T) T {
	var summation T
	for _, value := range slice {
		summation += value
	}
	return summation
}
