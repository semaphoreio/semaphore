// Package env holds a helper function for getting env variables.
package env

import (
	"log"
	"os"
)

func GetOrFail(variable string) string {
	value := os.Getenv(variable)
	if value == "" {
		log.Fatalf("%s is required", variable)
	}

	return value
}
