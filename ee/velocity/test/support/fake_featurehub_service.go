package support

import (
	"context"
	"os"
	"strconv"
	"time"

	featurepb "github.com/semaphoreio/semaphore/velocity/pkg/protos/feature"
)

type FakeFeatureServiceServer struct {
}

func (f FakeFeatureServiceServer) ListOrganizationFeatures(context context.Context, request *featurepb.ListOrganizationFeaturesRequest) (*featurepb.ListOrganizationFeaturesResponse, error) {
	var state featurepb.Availability_State
	var quantity int

	switch quotas := os.Getenv("SUPERJERRY_TESTS"); quotas {
	case "":
		state = featurepb.Availability_ENABLED
		quantity = 1
	case "disabled":
		state = featurepb.Availability_HIDDEN
		quantity = 0
	case "timeout":
		time.Sleep(time.Minute)
	default:
		state = featurepb.Availability_ENABLED
		count, _ := strconv.ParseInt(quotas, 10, 32)
		quantity = int(count)
	}

	return &featurepb.ListOrganizationFeaturesResponse{
		OrganizationFeatures: []*featurepb.OrganizationFeature{
			{
				Feature: &featurepb.Feature{
					Type: "superjerry_tests",
					Availability: &featurepb.Availability{
						State:    state,
						Quantity: uint32(quantity),
					},
				},
				Availability: &featurepb.Availability{
					State:    state,
					Quantity: uint32(quantity),
				},
			},
		},
	}, nil
}

func (f FakeFeatureServiceServer) ListFeatures(context.Context, *featurepb.ListFeaturesRequest) (*featurepb.ListFeaturesResponse, error) {
	return nil, nil
}

func (f FakeFeatureServiceServer) ListOrganizationMachines(context.Context, *featurepb.ListOrganizationMachinesRequest) (*featurepb.ListOrganizationMachinesResponse, error) {
	return nil, nil
}

func (f FakeFeatureServiceServer) ListMachines(context.Context, *featurepb.ListMachinesRequest) (*featurepb.ListMachinesResponse, error) {
	return nil, nil
}
