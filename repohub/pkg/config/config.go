package config

import (
	"log"
	"os"
)

func ProjectAPIEndpoint() string {
	return os.Getenv("INTERNAL_API_URL_PROJECT")
}

func UserAPIEndpoint() string {
	return os.Getenv("INTERNAL_API_URL_USER")
}

func RepositoryIntegratorAPIEndpoint() string {
	return os.Getenv("INTERNAL_API_URL_REPOSITORY_INTEGRATOR")
}

type DbConfig struct {
	DbHost          string
	DbPort          string
	DbName          string
	DbUser          string
	DbPass          string
	Ssl             string
	ApplicationName string
}

func DbConfiguration() DbConfig {
	if os.Getenv("DB_HOST") == "" {
		log.Fatalf("DB_HOST env var not set")
	}

	postgresDbSSL := os.Getenv("POSTGRES_DB_SSL")
	sslMode := "disable"
	if postgresDbSSL == "true" {
		sslMode = "require"
	}

	return DbConfig{
		DbHost:          os.Getenv("DB_HOST"),
		DbPort:          os.Getenv("DB_PORT"),
		DbName:          os.Getenv("DB_NAME"),
		DbPass:          os.Getenv("DB_PASSWORD"),
		DbUser:          os.Getenv("DB_USERNAME"),
		Ssl:             sslMode,
		ApplicationName: os.Getenv("APPLICATION_NAME"),
	}
}
