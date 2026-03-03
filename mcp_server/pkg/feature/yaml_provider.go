package feature

import (
	"context"
	"io/ioutil"
	"os"

	log "github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"

	"github.com/semaphoreio/semaphore/mcp_server/pkg/utils"
)

type YamlProvider struct {
	filename             string
	OrganizationFeatures []OrganizationFeature
}

type yamlFeature struct {
	Quantity *int  `yaml:"quantity,omitempty"`
	Enabled  *bool `yaml:"enabled,omitempty"`
}

func (f yamlFeature) ToOrganizationFeature(name string) OrganizationFeature {
	state := Hidden
	if f.Enabled == nil || *f.Enabled {
		state = Enabled
	}

	quantity := uint32(1)
	if f.Quantity != nil && *f.Quantity >= 0 {
		if safeQuantity, err := utils.IntToUint32(*f.Quantity, "quantity"); err != nil {
			log.WithField("feature", name).Warnf("Ignoring invalid quantity: %v", err)
		} else {
			quantity = safeQuantity
		}
	}

	return OrganizationFeature{
		Name:     name,
		Quantity: quantity,
		State:    state,
	}
}

func NewYamlProvider(filename string) (*YamlProvider, error) {
	provider := &YamlProvider{
		filename: filename,
	}

	if err := provider.loadFeatures(); err != nil {
		return nil, err
	}

	return provider, nil
}

func (p *YamlProvider) ListFeatures(orgId string) ([]OrganizationFeature, error) {
	return p.OrganizationFeatures, nil
}

func (p *YamlProvider) ListFeaturesWithContext(ctx context.Context, orgId string) ([]OrganizationFeature, error) {
	return p.OrganizationFeatures, nil
}

func (p *YamlProvider) loadFeatures() error {
	if p.OrganizationFeatures != nil {
		return nil
	}

	if err := p.validateFile(); err != nil {
		return err
	}

	yamlFile, err := ioutil.ReadFile(p.filename)
	if err != nil {
		log.Errorf("Reading '%s' failed with %v", p.filename, err)
		return err
	}

	yamlFeatures := make(map[string]yamlFeature)
	err = yaml.Unmarshal(yamlFile, &yamlFeatures)
	if err != nil {
		log.Errorf("Unmarshaling results from yaml failed: %v", err)
		return err
	}

	p.OrganizationFeatures = make([]OrganizationFeature, 0, len(yamlFeatures))

	for featureName, feature := range yamlFeatures {
		organizationFeature := feature.ToOrganizationFeature(featureName)
		p.OrganizationFeatures = append(p.OrganizationFeatures, organizationFeature)
	}

	return nil
}

func (p *YamlProvider) validateFile() error {
	_, err := os.Stat(p.filename)
	if err != nil {
		log.Errorf("File '%s' does not exist. Can't load features from YAML", p.filename)
		return err
	}
	return nil
}
