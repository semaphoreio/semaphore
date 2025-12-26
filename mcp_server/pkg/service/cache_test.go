// Package service holds grpc service's client implementations
package service

import (
	"context"
	"encoding/gob"
	"reflect"
	"testing"

	"github.com/google/go-cmp/cmp"
	"github.com/google/go-cmp/cmp/cmpopts"
	"github.com/semaphoreio/semaphore/mcp_server/pkg/internal_api/feature"
	"github.com/stretchr/testify/assert"
)

func init() {
	gob.Register(struct{ Name string }{})
}

func TestCacheGoClient_GetSet(t *testing.T) {
	client := NewCacheService()

	testCases := []struct {
		name    string
		key     string
		value   interface{}
		wantErr bool
	}{
		{
			name:    "Caching strings",
			key:     "key1",
			value:   "value1",
			wantErr: false,
		},
		{
			name:    "Caching structs",
			key:     "key1",
			value:   struct{ Name string }{Name: "value2"},
			wantErr: false,
		},
		{
			name:    "Caching integers",
			key:     "key1",
			value:   123,
			wantErr: false,
		},
		{
			name:    "Caching bools",
			key:     "key1",
			value:   false,
			wantErr: false,
		},
		{
			name:    "Caching feature.ListOrganizationFeaturesResponse",
			key:     "key1",
			value:   feature.ListOrganizationFeaturesResponse{OrganizationFeatures: []*feature.OrganizationFeature{{RequesterId: "123"}}},
			wantErr: false,
		},
	}

	for _, tc := range testCases {
		err := client.Set(context.Background(), tc.key, tc.value)
		assert.Nil(t, err)

		var got interface{}
		switch tc.value.(type) {
		case string:
			got = new(string)
		case int:
			got = new(int)
		case bool:
			got = new(bool)
		case struct{ Name string }:
			got = new(struct{ Name string })
		case feature.ListOrganizationFeaturesResponse:
			got = new(feature.ListOrganizationFeaturesResponse)
		default:
			t.Fatalf("Unsupported type in test case: %v", tc.value)
		}

		err = client.Get(context.Background(), tc.key, got)
		assert.Nil(t, err)

		gotDeref := reflect.ValueOf(got).Elem().Interface()
		if diff := cmp.Diff(tc.value, gotDeref, cmp.AllowUnexported(feature.ListOrganizationFeaturesResponse{}, feature.OrganizationFeature{}), cmpopts.IgnoreUnexported(feature.ListOrganizationFeaturesResponse{}, feature.OrganizationFeature{})); diff != "" {
			t.Fatalf("Assertion '%s' failed.\nDiff:%s\n", tc.name, diff)
		}
	}
}
