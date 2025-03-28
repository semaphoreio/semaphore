package installation

import (
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/clients"
	"github.com/semaphoreio/semaphore/bootstrapper/pkg/retry"
	log "github.com/sirupsen/logrus"
)

func ConfigureInstallationDefaults(instanceConfigClient *clients.InstanceConfigClient, orgId string) (map[string]string, error) {
	installationDefaults := installationDefaultsParams(orgId)
	err := retry.WithConstantWait("Installation Defaults configuration", 5, 10*time.Second, func() error {
		err := instanceConfigClient.ConfigureInstallationDefaults(installationDefaults)
		if err == nil {
			log.Info("Successfully configured Installation Defaults")
			return nil
		}

		return err
	})

	return installationDefaults, err
}

func installationDefaultsParams(orgId string) map[string]string {
	return map[string]string{
		"organization_id":    orgId,
		"telemetry_endpoint": getTelemetryEndpoint(),
		"installation_id":    uuid.New().String(),
		"kube_version":       getKubeVersion(),
	}
}

func getTelemetryEndpoint() string {
	telemetryEndpoint := os.Getenv("TELEMETRY_ENDPOINT")
	log.Infof("Telemetry endpoint: %s", telemetryEndpoint)

	if telemetryEndpoint == "" {
		telemetryEndpoint = "https://telemetry.semaphore.io/ingest"
	}

	return telemetryEndpoint
}

func getKubeVersion() string {
	kubeVersion := os.Getenv("KUBE_VERSION")
	log.Infof("Kube version: %s", kubeVersion)

	if kubeVersion == "" {
		kubeVersion = "unspecified"
	}

	return kubeVersion
}
