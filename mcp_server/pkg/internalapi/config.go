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
)

// Config captures the connection settings for talking to internal API services.
type Config struct {
	WorkflowEndpoint     string
	OrganizationEndpoint string
	ProjectEndpoint      string
	PipelineEndpoint     string
	JobEndpoint          string
	LoghubEndpoint       string
	Loghub2Endpoint      string
	UserEndpoint         string

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
		LoghubEndpoint:       endpointFromEnv(loghubEndpointEnvs...),
		Loghub2Endpoint:      endpointFromEnv(loghub2EndpointEnvs...),
		UserEndpoint:         endpointFromEnv(userEndpointEnvs...),
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
