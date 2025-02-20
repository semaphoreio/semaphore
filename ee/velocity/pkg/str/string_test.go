package str

import (
	"fmt"
	"testing"
)

func TestAnyEmpty(t *testing.T) {
	type args struct {
		v []string
	}
	tests := []struct {
		name string
		args args
		want bool
	}{
		{
			name: "empty array",
			args: struct{ v []string }{v: []string{}},
			want: false,
		},
		{
			name: "no empty strings",
			args: struct{ v []string }{v: []string{"hello", "its", "me"}},
			want: false,
		},
		{
			name: "one empty string",
			args: struct{ v []string }{v: []string{"hello", "", "me"}},
			want: true,
		},
		{
			name: "two empty string",
			args: struct{ v []string }{v: []string{"hello", "", "me", "I", "am", "", "in", "California"}},
			want: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := AnyEmpty(tt.args.v...); got != tt.want {
				t.Errorf("AnyEmpty() = %v, want %v", got, tt.want)
			}
		})
	}
}

func ExampleAnyEmpty() {
	fmt.Println(AnyEmpty("hello", "", "world"))
	// Output: true
}

func ExampleAnyEmpty_second() {
	fmt.Println(AnyEmpty())
	// Output: false
}

func ExampleAnyEmpty_third() {
	fmt.Println(AnyEmpty("hello", "world"))
	// Output: false
}

func TestIsEmpty(t *testing.T) {
	tests := []struct {
		name string
		args string
		want bool
	}{
		{
			name: "Non empty string",
			args: "hello world",
			want: false,
		},
		{
			name: "empty string",
			args: "",
			want: true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsEmpty(tt.args); got != tt.want {
				t.Errorf("IsEmpty() = %v, want %v", got, tt.want)
			}
		})
	}
}

func ExampleIsEmpty() {
	fmt.Println(IsEmpty(""))
	// Output: true
}

func ExampleIsEmpty_second() {
	fmt.Println(IsEmpty("not empty"))
	// Output: false
}
