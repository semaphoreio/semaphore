package feature

import "context"

type FeatureProvider interface {
	ListFeatures(orgId string) ([]OrganizationFeature, error)
	ListFeaturesWithContext(ctx context.Context, orgId string) ([]OrganizationFeature, error)
}

type State int

const (
	Enabled   State = 0
	Hidden    State = 1
	ZeroState State = 2
)

type OrganizationFeature struct {
	Name     string
	State    State
	Quantity uint32
}
