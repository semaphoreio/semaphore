// Package config has helper functions to set up connections with databases and grpc services.
package config

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/semaphoreio/semaphore/velocity/pkg/env"
)

var (
	FakeServerPortInTests = 0
)

func PlumberEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "ppl:50053"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func ArtifactHubEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "artifacthub-internal-grpc-api:50051"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func ProjectHubEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "projecthub-grpc:50051"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func ServerFarmEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "semaphore-job-api:50051"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func FeatureHubEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "feature-hub:50052"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func SuperjerryEndpoint() string {
	if flag.Lookup("test.v") == nil {
		return "dns:///superjerry-ingest-api:50051"
	}

	return fmt.Sprintf("0.0.0.0:%d", FakeServerPortInTests)
}

func GrpcCallTimeout() time.Duration {
	return 15
}

func SuperjerryGrpcCallTimeout() time.Duration {
	return 60
}

type DbConfig struct {
	Host            string
	Port            string
	Name            string
	User            string
	Password        string
	Ssl             string
	ApplicationName string
}

func DatabaseConfiguration() DbConfig {
	postgresDbSSL := os.Getenv("POSTGRES_DB_SSL")
	sslMode := "disable"
	if postgresDbSSL == "true" {
		sslMode = "require"
	}

	return DbConfig{
		Host:            env.GetOrFail("DB_HOST"),
		Port:            env.GetOrFail("DB_PORT"),
		Name:            env.GetOrFail("DB_NAME"),
		User:            env.GetOrFail("DB_USERNAME"),
		Password:        env.GetOrFail("DB_PASSWORD"),
		Ssl:             sslMode,
		ApplicationName: "velocity",
	}
}
