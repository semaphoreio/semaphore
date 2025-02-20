package grpcmock

import (
	"context"
	"os"
	"strconv"
	"time"

	featurepb "github.com/semaphoreio/semaphore/self_hosted_hub/pkg/protos/feature"
)

type FeatureService struct {
}

func NewFeatureService() FeatureService {
	return FeatureService{}
}

func (f FeatureService) ListOrganizationFeatures(context context.Context, request *featurepb.ListOrganizationFeaturesRequest) (*featurepb.ListOrganizationFeaturesResponse, error) {
	var state featurepb.Availability_State
	var quantity int

	switch quotas := os.Getenv("SELF_HOSTED_QUOTAS"); quotas {
	case "":
		state = featurepb.Availability_ENABLED
		quantity = 5
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
					Type: "self_hosted_agents",
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

func (f FeatureService) ListFeatures(context.Context, *featurepb.ListFeaturesRequest) (*featurepb.ListFeaturesResponse, error) {
	return nil, nil
}

func (f FeatureService) ListOrganizationMachines(context.Context, *featurepb.ListOrganizationMachinesRequest) (*featurepb.ListOrganizationMachinesResponse, error) {
	return nil, nil
}

func (f FeatureService) ListMachines(context.Context, *featurepb.ListMachinesRequest) (*featurepb.ListMachinesResponse, error) {
	return nil, nil
}
