package telemetry

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"

	log "github.com/sirupsen/logrus"
)

type RequestPayload struct {
	OrganizationId  string `json:"organization_id"`
	InstallationId  string `json:"installation_id"`
	KubeVersion     string `json:"kube_version"`
	Version         string `json:"version"`
	ProjectsCount   int    `json:"projects_count"`
	OrgMembersCount int    `json:"org_members_count"`
	State           string `json:"state"`
}

type TelemetryClient struct {
	chartVersion string
}

func NewTelemetryClient(chartVersion string) *TelemetryClient {
	return &TelemetryClient{
		chartVersion: chartVersion,
	}
}

func (c *TelemetryClient) SendTelemetryInstallationData(installationDefaults map[string]string) {
	endpoint := installationDefaults["telemetry_endpoint"]

	request := RequestPayload{
		OrganizationId:  installationDefaults["organization_id"],
		InstallationId:  installationDefaults["installation_id"],
		KubeVersion:     installationDefaults["kube_version"],
		Version:         c.chartVersion,
		ProjectsCount:   0,
		OrgMembersCount: 1,
		State:           "installed",
	}

	jsonData, err := json.Marshal(request)
	if err != nil {
		log.Errorf("Failed to marshal request payload: %v", err)
		return
	}

	req, err := buildPostRequest(endpoint, bytes.NewBuffer(jsonData))
	if err != nil {
		log.Errorf("Failed to build request: %v", err)
		return
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Errorf("Failed to send request: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode > 299 {
		log.Errorf("Failed to send request: %v", resp.Status)
		return
	}

	log.Info("Successfully sent telemetry installation data")
}

func buildPostRequest(uri string, body io.Reader) (*http.Request, error) {
	req, err := http.NewRequest(http.MethodPost, uri, body)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")

	return req, nil
}
