package privateapi

import (
	"testing"

	"github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacthub"
	artifacts "github.com/semaphoreio/semaphore/artifacthub/pkg/api/descriptors/artifacts"
)

func TestConvertSignedURLMethod(t *testing.T) {
	testCases := []struct {
		name     string
		input    artifacts.SignedURL_Method
		expected artifacthub.SignedURL_Method
	}{
		{name: "get", input: artifacts.SignedURL_GET, expected: artifacthub.SignedURL_GET},
		{name: "delete", input: artifacts.SignedURL_DELETE, expected: artifacthub.SignedURL_DELETE},
		{name: "head", input: artifacts.SignedURL_HEAD, expected: artifacthub.SignedURL_HEAD},
		{name: "put", input: artifacts.SignedURL_PUT, expected: artifacthub.SignedURL_PUT},
		{name: "post", input: artifacts.SignedURL_POST, expected: artifacthub.SignedURL_POST},
		{name: "unknown defaults to get", input: artifacts.SignedURL_Method(99), expected: artifacthub.SignedURL_GET},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			got := convertSignedURLMethod(tc.input)
			if got != tc.expected {
				t.Fatalf("expected %v, got %v", tc.expected, got)
			}
		})
	}
}

func TestNormalizePathLimit(t *testing.T) {
	testCases := []struct {
		name     string
		input    int32
		expected int
	}{
		{name: "zero means no limit", input: 0, expected: 0},
		{name: "negative means no limit", input: -1, expected: 0},
		{name: "positive value is preserved", input: 42, expected: 42},
		{name: "value above max is clamped", input: MaxPathItems + 1, expected: int(MaxPathItems)},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			got := normalizePathLimit(tc.input)
			if got != tc.expected {
				t.Fatalf("expected %d, got %d", tc.expected, got)
			}
		})
	}
}
