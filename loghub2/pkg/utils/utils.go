package utils

import (
	"fmt"
	"log"
	"os"
	"time"
)

func ClientConnectionName() string {
	hostname := os.Getenv("HOSTNAME")
	if hostname == "" {
		return "loghub2"
	}

	return hostname
}

func RetryWithConstantWait(task string, maxAttempts int, wait time.Duration, f func() error) error {
	for attempt := 1; ; attempt++ {
		err := f()
		if err == nil {
			return nil
		}

		if attempt > maxAttempts {
			return fmt.Errorf("[%s] failed after [%d] attempts - giving up: %v", task, attempt, err)
		}

		log.Printf("[%s] attempt [%d] failed with [%v] - retrying in %s", task, attempt, err, wait)
		time.Sleep(wait)
	}
}

func AssertEnvVar(varName string) string {
	varValue := os.Getenv(varName)
	if varValue == "" {
		log.Fatalf("%s can't be empty", varName)
	}

	return varValue
}

func FilterEmpty(list []string) []string {
	filteredList := []string{}
	for _, item := range list {
		if item != "" {
			filteredList = append(filteredList, item)
		}
	}

	return filteredList
}
