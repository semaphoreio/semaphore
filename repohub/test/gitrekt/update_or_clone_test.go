package gitrekt_test

import (
	"os"
	"os/exec"
	"testing"

	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
	assert "github.com/stretchr/testify/assert"
)

func Test__Update__UpdatesRemoteURLWhenChanged(t *testing.T) {
	oldURL := "https://github.com/old-org/old-repo.git"
	newURL := "https://github.com/new-org/new-repo.git"

	repo := &gitrekt.Repository{
		Name:    "test-update-remote-url",
		HttpURL: oldURL,
		Credentials: &gitrekt.Credentials{
			Username: "test",
			Password: "test",
		},
	}

	defer os.RemoveAll(repo.Path())

	// Initialize a bare repo with the old origin URL.
	cmds := [][]string{
		{"mkdir", "-p", repo.Path()},
		{"git", "init", "--bare"},
		{"git", "remote", "add", "origin", oldURL},
	}
	for _, args := range cmds {
		cmd := exec.Command(args[0], args[1:]...)
		cmd.Dir = repo.Path()
		out, err := cmd.CombinedOutput()
		assert.Nil(t, err, "command %v failed: %s", args, string(out))
	}

	// Update the URL and run Update.
	// Fetch will fail (no real remote), but set-url should succeed before that.
	repo.HttpURL = newURL
	op := gitrekt.NewUpdateOrCloneOperation(repo, "")
	_ = op.Update()

	// Verify the remote URL was updated.
	cmd := exec.Command("git", "remote", "get-url", "origin")
	cmd.Dir = repo.Path()
	out, err := cmd.CombinedOutput()
	assert.Nil(t, err)
	assert.Equal(t, newURL+"\n", string(out))
}
