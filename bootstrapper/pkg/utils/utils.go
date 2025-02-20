package utils

import (
	"os"

	log "github.com/sirupsen/logrus"
)

func AssertEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("%s env variable is required", key)
	}
	return value
}
