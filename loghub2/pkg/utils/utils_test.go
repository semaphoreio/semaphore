package utils

import (
	"errors"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func Test__ClientConnectionNameWithHostnameEnvVar(t *testing.T) {
	os.Setenv("HOSTNAME", "foobar2000")
	assert.Equal(t, ClientConnectionName(), "foobar2000")
	os.Unsetenv("HOSTNAME")
}

func Test__ClientConnectionNameWithoutHostnameEnvVar(t *testing.T) {
	assert.Equal(t, ClientConnectionName(), "loghub2")
}

func Test__NoRetriesIfFirstAttemptIsSuccessful(t *testing.T) {
	attempts := 0
	err := RetryWithConstantWait("test", 5, 100*time.Millisecond, func() error {
		attempts++
		return nil
	})
	assert.Equal(t, attempts, 1)
	assert.Nil(t, err)
}

func Test__GivesUpAfterMaxRetries(t *testing.T) {
	attempts := 0
	err := RetryWithConstantWait("test", 5, 100*time.Millisecond, func() error {
		attempts++
		return errors.New("bad error")
	})
	assert.Equal(t, attempts, 6)
	assert.NotNil(t, err)
}
