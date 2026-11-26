package database

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
)

// Every pod runs the migrations on start. A pod waiting for the migration lock holds a snapshot
// that a concurrent index build waits for, so the two deadlock and the build can be the one cancelled.
func Test__MigrationsDoNotBuildIndexesConcurrently(t *testing.T) {
	files, err := filepath.Glob("../../db/migrations/*.sql")
	require.NoError(t, err)
	require.NotEmpty(t, files)

	for _, file := range files {
		content, err := os.ReadFile(filepath.Clean(file))
		require.NoError(t, err)
		require.NotContains(t, strings.ToUpper(string(content)), "CONCURRENTLY", file)
	}
}
