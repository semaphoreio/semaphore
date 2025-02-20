package clients

import (
	"context"
	"fmt"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/config"
	protoconfig "github.com/semaphoreio/semaphore/bootstrapper/pkg/protos/instance_config"
	log "github.com/sirupsen/logrus"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type InstanceConfigClient struct {
	client protoconfig.InstanceConfigServiceClient
}

func NewInstanceConfigClient() *InstanceConfigClient {
	conn, err := grpc.NewClient(config.InstanceConfigEndpoint(), grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("Failed to connect to instance config service: %v", err)
	}

	client := protoconfig.NewInstanceConfigServiceClient(conn)

	return &InstanceConfigClient{
		client: client,
	}
}

func (c *InstanceConfigClient) ConfigureGitHubApp(params map[string]string) error {
	return c.configure(params, protoconfig.ConfigType_CONFIG_TYPE_GITHUB_APP, "Github App")
}

func (c *InstanceConfigClient) ConfigureGitlabApp(params map[string]string) error {
	return c.configure(params, protoconfig.ConfigType_CONFIG_TYPE_GITLAB_APP, "Gitlab App")
}

func (c *InstanceConfigClient) ConfigureBitbucketApp(params map[string]string) error {
	return c.configure(params, protoconfig.ConfigType_CONFIG_TYPE_BITBUCKET_APP, "Bitbucket App")
}

func (c *InstanceConfigClient) ConfigureInstallationDefaults(params map[string]string) error {
	return c.configure(params, protoconfig.ConfigType_CONFIG_TYPE_INSTALLATION_DEFAULTS, "Installation defaults")
}

func (c *InstanceConfigClient) configure(params map[string]string, configType protoconfig.ConfigType, configName string) error {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)
	defer cancel()

	fields := []*protoconfig.ConfigField{}
	for k, v := range params {
		if v == "" {
			return fmt.Errorf("Empty %s configuration for %s", k, configName)
		}

		fields = append(fields, &protoconfig.ConfigField{
			Key:   k,
			Value: v,
		})
	}

	req := &protoconfig.ModifyConfigRequest{
		Config: &protoconfig.Config{
			Type:   configType,
			State:  protoconfig.State_STATE_CONFIGURED,
			Fields: fields,
		},
	}

	_, err := c.client.ModifyConfig(ctx, req)
	if err != nil {
		log.Errorf("Failed to configure %s: %v", configName, err)
		return err
	}

	log.Infof("Configured %s", configName)
	return nil
}
