package internalapi

import (
	"fmt"
	"os"
	"strings"
	"time"
)

const (
	envWorkflowEndpoint = "MCP_WORKFLOW_GRPC_ENDPOINT"
	envPipelineEndpoint = "MCP_PIPELINE_GRPC_ENDPOINT"
	envJobEndpoint      = "MCP_JOB_GRPC_ENDPOINT"
	envLoghubEndpoint   = "MCP_LOGHUB_GRPC_ENDPOINT"
	envLoghub2Endpoint  = "MCP_LOGHUB2_GRPC_ENDPOINT"

	fallbackWorkflow = "WF_GRPC_URL"
	fallbackPipeline = "PPL_GRPC_URL"
	fallbackJob      = "JOBS_API_URL"
	fallbackLoghub   = "LOGHUB_API_URL"
	fallbackLoghub2  = "LOGHUB2_API_URL"

	envDialTimeout = "MCP_GRPC_DIAL_TIMEOUT"
	envCallTimeout = "MCP_GRPC_CALL_TIMEOUT"
)

// Config captures the connection settings for talking to internal API services.
type Config struct {
	WorkflowEndpoint string
	PipelineEndpoint string
	JobEndpoint      string
	LoghubEndpoint   string
	Loghub2Endpoint  string

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
		WorkflowEndpoint: endpointFromEnv(envWorkflowEndpoint, fallbackWorkflow),
		PipelineEndpoint: endpointFromEnv(envPipelineEndpoint, fallbackPipeline),
		JobEndpoint:      endpointFromEnv(envJobEndpoint, fallbackJob),
		LoghubEndpoint:   endpointFromEnv(envLoghubEndpoint, fallbackLoghub),
		Loghub2Endpoint:  endpointFromEnv(envLoghub2Endpoint, fallbackLoghub2),
		DialTimeout:      dialTimeout,
		CallTimeout:      callTimeout,
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

func endpointFromEnv(primary, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(primary)); v != "" {
		return v
	}
	if fallback == "" {
		return ""
	}
	return strings.TrimSpace(os.Getenv(fallback))
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
