package calc

import (
	"github.com/stretchr/testify/assert"
	"reflect"
	"testing"
	"time"
)

func TestMax(t *testing.T) {
	type args struct {
		slice []int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{name: "one", args: args{slice: []int{1}}, want: 1},
		{name: "two", args: args{slice: []int{1, 2}}, want: 2},
		{name: "three", args: args{slice: []int{1, 2, 3}}, want: 3},
		{name: "four", args: args{slice: []int{1, 2, 3, 4}}, want: 4},
		{name: "all negative numbers", args: args{slice: []int{-1, -2, -3, -4}}, want: -1},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Max(tt.args.slice); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Max() = %v, want %v", got, tt.want)
			}
		})
	}
}

type Nested struct {
	Value int
}

func TestMaxFunc(t *testing.T) {

	type args struct {
		slice []Nested
		f     func(Nested) int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{name: "one", args: args{slice: []Nested{{Value: 1}}, f: func(n Nested) int { return n.Value }}, want: 1},
		{name: "two", args: args{slice: []Nested{{Value: 2}, {Value: 2}}, f: func(n Nested) int { return n.Value }}, want: 2},
		{name: "three", args: args{slice: []Nested{{Value: 1}, {Value: 3}, {Value: 2}}, f: func(n Nested) int { return n.Value }}, want: 3},
		{name: "four", args: args{slice: []Nested{{Value: 4}, {Value: 2}, {Value: 3}, {Value: 4}}, f: func(n Nested) int { return n.Value }}, want: 4},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := MaxFunc(tt.args.slice, tt.args.f); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("MaxFunc() = %v, want %v", got, tt.want)
			}
		})
	}
}
func TestMin(t *testing.T) {
	type args struct {
		slice []int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{name: "one elems", args: args{slice: []int{1}}, want: 1},
		{name: "two elems", args: args{slice: []int{2, 1}}, want: 1},
		{name: "three elems", args: args{slice: []int{2, 1, 3}}, want: 1},
		{name: "four elems should return -3", args: args{slice: []int{1, 2, -3, 4}}, want: -3},
		{name: "four elems should return -15", args: args{slice: []int{1, -15, 3, 4}}, want: -15},
		{name: "four elems should return -2", args: args{slice: []int{1, 2, 3, -2}}, want: -2},
		{name: "four elems should return -6", args: args{slice: []int{-6, 2, 3, 4}}, want: -6},
		{name: "four elems should return -11", args: args{slice: []int{1, 2, -11, 4}}, want: -11},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Min(tt.args.slice); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("Min() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestMinFunc(t *testing.T) {

	type args struct {
		slice []Nested
		f     func(Nested) int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{name: "one", args: args{slice: []Nested{{Value: 1}}, f: func(n Nested) int { return n.Value }}, want: 1},
		{name: "two", args: args{slice: []Nested{{Value: 2}, {Value: 2}}, f: func(n Nested) int { return n.Value }}, want: 2},
		{name: "three", args: args{slice: []Nested{{Value: 1}, {Value: -3}, {Value: 2}}, f: func(n Nested) int { return n.Value }}, want: -3},
		{name: "four", args: args{slice: []Nested{{Value: 4}, {Value: 2}, {Value: 3}, {Value: -4}}, f: func(n Nested) int { return n.Value }}, want: -4},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := MinFunc(tt.args.slice, tt.args.f); !reflect.DeepEqual(got, tt.want) {
				t.Errorf("MinFunc() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestAverage(t *testing.T) {
	type args struct {
		slice []int
	}
	tests := []struct {
		name string
		args args
		want int
	}{
		{name: "one", args: args{slice: []int{1}}, want: 1},
		{name: "two", args: args{slice: []int{1, 2}}, want: 1},
		{name: "three", args: args{slice: []int{1, 2, 3}}, want: 2},
		{name: "four", args: args{slice: []int{1, 2, 3, 4}}, want: 2},
		{name: "five", args: args{slice: []int{1, 2, 3, 4, 5}}, want: 3},
		{name: "six", args: args{slice: []int{1, 2, 3, 4, 5, 6}}, want: 3},
		{name: "seven", args: args{slice: []int{1, 2, 3, 4, 5, 6, 7}}, want: 4},
		{name: "eight", args: args{slice: []int{8, 2, 5, 4, 3, 6, 7, 1}}, want: 4},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := Average(tt.args.slice); got != tt.want {
				t.Errorf("Average() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestStdDev(t *testing.T) {
	type args struct {
		slice []float64
	}
	tests := []struct {
		name string
		args args
		want float64
	}{
		{name: "one number", args: args{slice: []float64{1}}, want: 0},
		{name: "std sample 1", args: args{slice: []float64{9, 2, 5, 4, 12, 7, 8, 11, 9, 3, 7, 4, 12, 5, 4, 10, 9, 6, 9, 4}}, want: 2.9832867780352594},
		{name: "std sample 2", args: args{slice: []float64{-5, 1, 8, 7, 2, -55, 1, 25, 4, 99, 12}}, want: 34.19728856875272},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := StdDev(tt.args.slice); got != tt.want {
				t.Errorf("StdDev() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestStdDevTime(t *testing.T) {
	type args struct {
		slice []time.Duration
	}
	tests := []struct {
		name string
		args args
		want time.Duration
	}{
		{name: "one number", args: args{slice: []time.Duration{1}}, want: 0},
		{name: "std sample 1", args: args{slice: applyDuration(time.Minute, []int{9, 2, 5, 4, 12, 7, 8, 11, 9, 3, 7, 4, 12, 5, 4, 10, 9, 6, 9, 4})}, want: 2*time.Minute + 58*time.Second},
		{name: "std sample 2", args: args{slice: applyDuration(time.Second, []int{-5, 1, 8, 7, 2, -55, 1, 25, 4, 99, 12})}, want: 34 * time.Second},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := StdDev(tt.args.slice)
			assert.WithinDuration(t, time.Now().Add(tt.want), time.Now().Add(got), time.Second)
		})
	}
}

func applyDuration(unit time.Duration, slice []int) []time.Duration {
	var durations []time.Duration
	for _, v := range slice {
		durations = append(durations, time.Duration(v)*unit)
	}
	return durations
}

func TestMedianFloat(t *testing.T) {
	type args struct {
		slice []float64
	}
	tests := []struct {
		name string
		args args
		want float64
	}{
		{name: "one number", args: args{slice: []float64{1}}, want: 1},
		{name: "two numbers", args: args{slice: []float64{1, 2}}, want: 1.5},
		{name: "three numbers", args: args{slice: []float64{1, 2, 3}}, want: 2},
		{name: "four numbers", args: args{slice: []float64{1, 2, 3, 4}}, want: 2.5},
		{name: "five numbers", args: args{slice: []float64{1, 2, 3, 4, 5}}, want: 3},
		{name: "six numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6}}, want: 3.5},
		{name: "seven numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6, 7}}, want: 4},
		{name: "eight numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6, 7, 8}}, want: 4.5},
		{name: "nine numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6, 7, 8, 9}}, want: 5},
		{name: "ten numbers", args: args{slice: []float64{10, 2, 9, 5, 6, 4, 7, 8, 3, 1}}, want: 5.5},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, Median(tt.args.slice), "Median(%v)", tt.args.slice)
		})
	}
}

func TestMedianTime(t *testing.T) {
	type args struct {
		slice []time.Duration
	}
	tests := []struct {
		name string
		args args
		want time.Duration
	}{
		{name: "one number", args: args{slice: applyDuration(time.Second, []int{1})}, want: 1 * time.Second},
		{name: "two numbers", args: args{slice: applyDuration(time.Second, []int{1, 2})}, want: 1*time.Second + 500*time.Millisecond},
		{name: "three numbers", args: args{slice: applyDuration(time.Second, []int{1, 2, 3})}, want: 2 * time.Second},
		{name: "four numbers", args: args{slice: applyDuration(time.Second, []int{1, 2, 3, 4})}, want: 2*time.Second + 500*time.Millisecond},
		{name: "five numbers", args: args{slice: applyDuration(time.Second, []int{1, 2, 3, 4, 5})}, want: 3 * time.Second},
		{name: "six numbers", args: args{slice: applyDuration(time.Second, []int{1, 2, 3, 4, 5, 6})}, want: 3*time.Second + 500*time.Millisecond},
		{name: "six numbers (minute)", args: args{slice: applyDuration(time.Minute, []int{1, 2, 3, 4, 5, 6})}, want: 3*time.Minute + 30*time.Second},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := Median(tt.args.slice)
			now := time.Now()
			assert.WithinDuration(t, now.Add(tt.want), now.Add(got), time.Millisecond)
		})
	}
}

func TestP95(t *testing.T) {
	type args struct {
		slice []float64
	}
	tests := []struct {
		name string
		args args
		want float64
	}{
		{name: "one number", args: args{slice: []float64{1}}, want: 1},
		{name: "two numbers", args: args{slice: []float64{1, 2}}, want: 2},
		{name: "three numbers", args: args{slice: []float64{1, 2, 3}}, want: 3},
		{name: "four numbers", args: args{slice: []float64{1, 2, 3, 4}}, want: 4},
		{name: "five numbers", args: args{slice: []float64{1, 2, 3, 4, 5}}, want: 5},
		{name: "six numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6}}, want: 6},
		{name: "seven numbers", args: args{slice: []float64{1, 2, 3, 4, 5, 6, 7}}, want: 7},
		{name: "twenty numbers", args: args{slice: []float64{34, 26, 33, 50, 22, 35, 37, 28, 39, 27, 11, 24, 29, 32, 31, 36, 23, 25, 30, 38}}, want: 39},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equalf(t, tt.want, P95(tt.args.slice), "P95(%v)", tt.args.slice)
		})
	}
}
