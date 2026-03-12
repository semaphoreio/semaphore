package internalapi

import (
	"fmt"
	"os"
	"strings"
	"time"
)

const (
	envDialTimeout = "MCP_GRPC_DIAL_TIMEOUT"
	envCallTimeout = "MCP_GRPC_CALL_TIMEOUT"
	envBaseURL     = "BASE_DOMAIN"
	defaultBaseURL = "semaphoreci.com"
)

var (
	workflowEndpointEnvs = []string{
		"INTERNAL_API_URL_PLUMBER",
		"MCP_WORKFLOW_GRPC_ENDPOINT",
		"WF_GRPC_URL",
	}
	organizationEndpointEnvs = []string{
		"INTERNAL_API_URL_ORGANIZATION",
		"MCP_ORGANIZATION_GRPC_ENDPOINT",
	}
	projectEndpointEnvs = []string{
		"INTERNAL_API_URL_PROJECT",
		"MCP_PROJECT_GRPC_ENDPOINT",
	}
	pipelineEndpointEnvs = []string{
		"INTERNAL_API_URL_PLUMBER",
		"MCP_PIPELINE_GRPC_ENDPOINT",
		"PPL_GRPC_URL",
	}
	jobEndpointEnvs = []string{
		"INTERNAL_API_URL_JOB",
		"MCP_JOB_GRPC_ENDPOINT",
		"JOBS_API_URL",
	}
	artifacthubEndpointEnvs = []string{
		"INTERNAL_API_URL_ARTIFACTHUB",
		"MCP_ARTIFACTHUB_GRPC_ENDPOINT",
	}
	loghubEndpointEnvs = []string{
		"INTERNAL_API_URL_LOGHUB",
		"MCP_LOGHUB_GRPC_ENDPOINT",
		"LOGHUB_API_URL",
	}
	loghub2EndpointEnvs = []string{
		"INTERNAL_API_URL_LOGHUB2",
		"MCP_LOGHUB2_GRPC_ENDPOINT",
		"LOGHUB2_API_URL",
	}
	userEndpointEnvs = []string{
		"INTERNAL_API_URL_USER",
		"MCP_USER_GRPC_ENDPOINT",
	}
	rbacEndpointEnvs = []string{
		"INTERNAL_API_URL_RBAC",
		"MCP_RBAC_GRPC_ENDPOINT",
	}
	featureHubEndpointEnvs = []string{
		"INTERNAL_API_URL_FEATURE",
		"MCP_FEATURE_GRPC_ENDPOINT",
	}
	schedulerEndpointEnvs = []string{
		"INTERNAL_API_URL_SCHEDULER",
		"MCP_SCHEDULER_GRPC_ENDPOINT",
	}
)

// Config captures the connection settings for talking to internal API services.
type Config struct {
	WorkflowEndpoint     string
	OrganizationEndpoint string
	ProjectEndpoint      string
	PipelineEndpoint     string
	JobEndpoint          string
	ArtifacthubEndpoint  string
	LoghubEndpoint       string
	Loghub2Endpoint      string
	UserEndpoint         string
	RBACEndpoint         string
	FeatureHubEndpoint   string
	SchedulerEndpoint    string

	BaseURL string

	DialTimeout time.Duration
	CallTimeout time.Duration
}

// LoadConfig reads configuration from environment variables.
func LoadConfig() (Config, error) {
	dialTimeout, err := durationFromEnv(envDialTimeout, 5*time.Second)
	if err != nil {
		return Config{}, err
	}
	callTimeout, err := durationFromEnv(envCallTimeout, 15*time.Second)
	if err != nil {
		return Config{}, err
	}

	cfg := Config{
		WorkflowEndpoint:     endpointFromEnv(workflowEndpointEnvs...),
		OrganizationEndpoint: endpointFromEnv(organizationEndpointEnvs...),
		ProjectEndpoint:      endpointFromEnv(projectEndpointEnvs...),
		PipelineEndpoint:     endpointFromEnv(pipelineEndpointEnvs...),
		JobEndpoint:          endpointFromEnv(jobEndpointEnvs...),
		ArtifacthubEndpoint:  endpointFromEnv(artifacthubEndpointEnvs...),
		LoghubEndpoint:       endpointFromEnv(loghubEndpointEnvs...),
		Loghub2Endpoint:      endpointFromEnv(loghub2EndpointEnvs...),
		UserEndpoint:         endpointFromEnv(userEndpointEnvs...),
		RBACEndpoint:         endpointFromEnv(rbacEndpointEnvs...),
		FeatureHubEndpoint:   endpointFromEnv(featureHubEndpointEnvs...),
		SchedulerEndpoint:    endpointFromEnv(schedulerEndpointEnvs...),
		BaseURL:              baseURLFromEnv(),
		DialTimeout:          dialTimeout,
		CallTimeout:          callTimeout,
	}

	if cfg.DialTimeout <= 0 {
		return Config{}, fmt.Errorf("invalid gRPC dial timeout: %s", cfg.DialTimeout)
	}
	if cfg.CallTimeout <= 0 {
		return Config{}, fmt.Errorf("invalid gRPC call timeout: %s", cfg.CallTimeout)
	}

	return cfg, nil
}

// Validate ensures mandatory endpoints are configured.
func (c Config) Validate() error {
	var missing []string
	if c.WorkflowEndpoint == "" {
		missing = append(missing, "workflow gRPC endpoint")
	}
	if c.OrganizationEndpoint == "" {
		missing = append(missing, "organization gRPC endpoint")
	}
	if c.ProjectEndpoint == "" {
		missing = append(missing, "project gRPC endpoint")
	}
	if c.PipelineEndpoint == "" {
		missing = append(missing, "pipeline gRPC endpoint")
	}
	if c.JobEndpoint == "" {
		missing = append(missing, "job gRPC endpoint")
	}
	if c.ArtifacthubEndpoint == "" {
		missing = append(missing, "artifacthub gRPC endpoint")
	}
	if c.RBACEndpoint == "" {
		missing = append(missing, "rbac gRPC endpoint")
	}
	if c.FeatureHubEndpoint == "" {
		missing = append(missing, "feature hub gRPC endpoint")
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}
	return nil
}

func endpointFromEnv(keys ...string) string {
	for _, key := range keys {
		if key == "" {
			continue
		}
		if v := strings.TrimSpace(os.Getenv(key)); v != "" {
			return v
		}
	}
	return ""
}

func durationFromEnv(key string, def time.Duration) (time.Duration, error) {
	raw := strings.TrimSpace(os.Getenv(key))
	if raw == "" {
		return def, nil
	}

	d, err := time.ParseDuration(raw)
	if err != nil {
		return 0, fmt.Errorf("invalid duration for %s: %w", key, err)
	}
	return d, nil
}

func baseURLFromEnv() string {
	if v := strings.TrimSpace(os.Getenv(envBaseURL)); v != "" {
		return v
	}
	return defaultBaseURL
}
