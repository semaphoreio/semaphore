package config

import (
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
)

func UserEndpoint() string {
	return utils.AssertEnv("INTERNAL_API_URL_USER")
}

func OrgEndpoint() string {
	return utils.AssertEnv("INTERNAL_API_URL_ORGANIZATION")
}

func SelfHostedEndpoint() string {
	return utils.AssertEnv("INTERNAL_API_URL_SELFHOSTEDHUB")
}

func InstanceConfigEndpoint() string {
	return utils.AssertEnv("INTERNAL_API_URL_INSTANCE_CONFIG")
}

func RepoProxyEndpoint() string {
	return utils.AssertEnv("INTERNAL_API_URL_REPO_PROXY")
}
