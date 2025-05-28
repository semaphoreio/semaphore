package cmd

import (
	"crypto/tls"
	"net/http"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/bootstrapper/pkg/bitbucket"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/github"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/gitlab"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/installation"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/kubernetes"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/organization"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/telemetry"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/user"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/utils"
	log "github.com/sirupsen/logrus"
	"github.com/spf13/cobra"
)

var initOrgCmd = &cobra.Command{
	Use:   "init-org",
	Short: "Initialize the organization after a fresh installation",
	Args:  cobra.NoArgs,
	Long:  ``,
	Run: func(cmd *cobra.Command, args []string) {
		log.Info("Initializing organization...")

		domain := utils.AssertEnv("BASE_DOMAIN")
		orgUsername := utils.AssertEnv("ORGANIZATION_USERNAME")
		userName := utils.AssertEnv("ROOT_NAME")
		userEmail := utils.AssertEnv("ROOT_EMAIL")
		authenticationSecretName := utils.AssertEnv("AUTHENTICATION_SECRET_NAME")

		kubernetesClient := kubernetes.NewClient()
		instanceConfigClient := clients.NewInstanceConfigClient()
		repoProxyClient := clients.NewRepoProxyClient()

		//
		// Before we proceed, we must ensure that the ingress is responding properly,
		// because the user creation requires HTTPS.
		//
		waitForIngress(domain)

		// First check if the organization already exists
		exists, existingOrgId := organization.OrganizationExists(orgUsername)
		if exists {
			log.Infof("Organization %s already exists with ID %s. Skipping organization creation.", orgUsername, existingOrgId)
			// Return early since organization already exists
			return
		}

		userId := user.CreateSemaphoreUser(kubernetesClient, userName, userEmail, authenticationSecretName)
		orgId := organization.CreateSemaphoreOrganization(orgUsername, userId)

		if os.Getenv("DEFAULT_AGENT_TYPE_ENABLED") == "true" {
			agentTypeSecretName := utils.AssertEnv("DEFAULT_AGENT_TYPE_SECRET_NAME")
			agentTypeName := utils.AssertEnv("DEFAULT_AGENT_TYPE_NAME")
			organization.CreateAgentType(kubernetesClient, orgId, userId, agentTypeSecretName, agentTypeName)
		}

		if os.Getenv("CONFIGURE_INSTALLATION_DEFAULTS") == "true" {
			telemetryClient := telemetry.NewTelemetryClient(os.Getenv("CHART_VERSION"))

			installationDefaults, err := installation.ConfigureInstallationDefaults(instanceConfigClient, orgId)
			if err == nil {
				telemetryClient.SendTelemetryInstallationData(installationDefaults)
			} else {
				log.Errorf("Failed to configure installation defaults: %v", err)
			}
		}

		if os.Getenv("CONFIGURE_GITHUB_APP") == "true" {
			appName := utils.AssertEnv("GITHUB_APPLICATION_NAME")
			if err := github.ConfigureApp(instanceConfigClient, repoProxyClient, appName); err != nil {
				log.Errorf("Failed to configure github app: %v", err)
			}
		}

		if os.Getenv("CONFIGURE_BITBUCKET_APP") == "true" {
			if err := bitbucket.ConfigureApp(instanceConfigClient); err != nil {
				log.Errorf("Failed to configure bitbucket app: %v", err)
			}
		}

		if os.Getenv("CONFIGURE_GITLAB_APP") == "true" {
			if err := gitlab.ConfigureApp(instanceConfigClient); err != nil {
				log.Errorf("Failed to configure gitlab app: %v", err)
			}
		}
	},
}

func waitForIngress(domain string) {
	url := "https://id." + domain + "/realms/semaphore/.well-known/openid-configuration"

	insecure := os.Getenv("TLS_SKIP_VERIFY_INTERNAL") == "true"

	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}
	if insecure {
		tlsConfig.InsecureSkipVerify = true // #nosec G402
	}

	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}

	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Add("Cache-Control", "no-cache, no-store, must-revalidate")
	req.Header.Add("Pragma", "no-cache")
	req.Header.Add("If-None-Match", "")
	req.Header.Add("If-Modified-Since", "")

	for {
		log.Infof("Request URL: %s", req.URL.String())
		log.Info("Waiting for ingress...")
		_, err := client.Do(req)
		if err == nil {
			log.Info("Ingress is ready")
			return
		}

		log.Errorf("Ingress is not available yet: %v", err)
		time.Sleep(5 * time.Second)
		continue
	}
}

func init() {
	RootCmd.AddCommand(initOrgCmd)
}
