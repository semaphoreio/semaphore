package gitrekt

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"slices"
	"strings"
	"syscall"
	"time"

	"github.com/renderedtext/go-watchman"
)

func UpdateOrClone(projectID string, repo *Repository, revision *Revision) (string, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.UpdateOrClone", []string{repo.HttpURL})

	reference := extractReference(revision)

	op := NewUpdateOrCloneOperation(projectID, repo, reference)
	err := op.Run()

	log.Printf("UpdateOrClone took %f seconds for %s %s (%s)", op.Duration(), repo.Name, projectID, repo.HttpURL)

	return op.Repository.Path(), err
}

//
// Internals
//

type UpdateOrCloneOperation struct {
	ProjectID  string
	Repository *Repository
	Reference  string
	Started    time.Time
	Finished   time.Time
}

func NewUpdateOrCloneOperation(projectID string, repo *Repository, reference string) *UpdateOrCloneOperation {
	return &UpdateOrCloneOperation{
		ProjectID:  projectID,
		Repository: repo,
		Reference:  reference,
	}
}

func (o *UpdateOrCloneOperation) Duration() float64 {
	return o.Finished.Sub(o.Started).Seconds()
}

func (o *UpdateOrCloneOperation) Run() error {
	var err error

	o.Started = time.Now()

	if o.Repository.Exists() {
		err = o.Update()
	} else {
		err = o.Clone()
	}

	o.Finished = time.Now()

	return err
}

func (o *UpdateOrCloneOperation) Update() error {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.UpdateOrClone.Update", []string{o.Repository.HttpURL})

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Minute)
	defer cancel()

	var cmd *exec.Cmd
	if o.Reference != "" {
		log.Printf("fetching from remotes %s with revision %v", o.Repository.Path(), o.Reference)

		// #nosec G204
		cmd = exec.CommandContext(ctx, "git", "fetch", "origin", o.Reference)
	} else {
		log.Printf("fetching from remotes %s without revision", o.Repository.Path())
		cmd = exec.CommandContext(ctx, "git", "fetch", "origin")
	}

	cmd.Dir = o.Repository.Path()
	cmd.Env = append(cmd.Env, "GIT_ASKPASS=/app/git-ask-pass.sh")
	cmd.Env = append(cmd.Env, fmt.Sprintf("GIT_USERNAME=%s", o.Repository.Credentials.Username))
	cmd.Env = append(cmd.Env, fmt.Sprintf("GIT_PASSWORD=%s", o.Repository.Credentials.Password))

	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("(err) Fetch repo %s, out: %s", o.Repository.HttpURL, string(out))
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) sparseClone() error {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.UpdateOrClone.SparseClone", []string{o.Repository.HttpURL})

	var err error
	log.Printf("Sparse cloning %s", o.Repository.Path())

	err = o.gitCloneSparse()
	if err != nil {
		cleanupDirectory(o)

		return err
	}

	err = o.gitSparseCheckoutInit()
	if err != nil {
		cleanupDirectory(o)

		return err
	}

	err = o.gitSparseSet()
	if err != nil {
		cleanupDirectory(o)

		return err
	}

	err = o.Update()
	if err != nil {
		cleanupDirectory(o)
		return err
	}

	return nil
}

func (o *UpdateOrCloneOperation) Clone() error {
	envValue := os.Getenv("USE_SPARSE_CLONES_FOR")
	if envValue == "" {
		log.Printf("Using bare clone for %s", o.ProjectID)
		return o.bareClone()
	}

	projectIDs := strings.Split(envValue, ",")
	if slices.Contains(projectIDs, o.ProjectID) {
		log.Printf("Using sparse clone for %s", o.ProjectID)
		return o.sparseClone()
	} else {
		log.Printf("Using bare clone for %s", o.ProjectID)
		return o.bareClone()
	}
}

func (o *UpdateOrCloneOperation) bareClone() error {
	var err error

	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.UpdateOrClone.Clone", []string{o.Repository.HttpURL})

	log.Printf("cloning %s", o.Repository.Path())

	err = o.mkdir()
	if err != nil {
		return err
	}

	err = o.gitInit()
	if err != nil {
		cleanupDirectory(o)

		return err
	}

	err = o.gitRemoteAdd()
	if err != nil {
		cleanupDirectory(o)
		return err
	}

	err = o.gitRemoteConfig()
	if err != nil {
		cleanupDirectory(o)
		return err
	}

	err = o.Update()
	if err != nil {
		cleanupDirectory(o)
		return err
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitCloneSparse() error {
	log.Printf("initializing bare repo %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(
		ctx,
		"git",
		"clone",
		"--no-checkout",
		"--filter=blob:none",
		o.Repository.Path(),
		o.Repository.HttpURL,
	)

	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Error sparse cloning repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitSparseCheckoutInit() error {
	log.Printf("initializing sparse for %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sparse-checkout", "init", "--cone")
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Error on sparse checkout init for %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitSparseSet() error {
	log.Printf("initializing sparse for %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "sparse-checkout", "set", ".semaphore")
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Error on sparse checkout init for %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) mkdir() error {
	log.Printf("setting up directory %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// We are in control of this path, so we can safely use cmd
	// #nosec G204
	cmd := exec.CommandContext(ctx, "mkdir", "-p", o.Repository.Path())
	out, err := cmd.CombinedOutput()

	if err != nil {
		log.Printf("(err) Clone repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) rmdir() error {
	log.Printf("removing directory %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// We are in control of this path, so we can safely use cmd
	// #nosec G204
	cmd := exec.CommandContext(ctx, "rm", "-rf", o.Repository.Path())
	out, err := cmd.CombinedOutput()

	if err != nil {
		log.Printf("(err) Clone repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitInit() error {
	log.Printf("initializing bare repo %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", "init", "--bare")
	cmd.Dir = o.Repository.Path()

	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("(err) Clone repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitRemoteAdd() error {
	log.Printf("adding git remote to repo %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// We are in control of this url, so we can safely use cmd
	// #nosec G204
	cmd := exec.CommandContext(ctx, "git", "remote", "add", "origin", o.Repository.HttpURL)
	cmd.Dir = o.Repository.Path()

	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("(err) Clone repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) gitRemoteConfig() error {
	log.Printf("configuring git remote in repo %s", o.Repository.Path())

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "git", "config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*")
	cmd.Dir = o.Repository.Path()

	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("(err) Clone repo %s, out: %s, err: %s", o.Repository.HttpURL, string(out), err.Error())
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) parseError(output []byte, err error) error {
	if strings.Contains(string(output), "remote: Repository not found") {
		return &NotFoundError{}
	}

	if strings.Contains(string(output), "fatal: Authentication failed") {
		return &AuthFailedError{}
	}

	if exiterr, ok := err.(*exec.ExitError); ok {
		if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
			if status.ExitStatus() == -1 && strings.Contains(err.Error(), "killed") {
				return &TimeoutError{}
			}
		}
	}

	return fmt.Errorf("err: %s: %v", output, err)
}

func cleanupDirectory(o *UpdateOrCloneOperation) {
	err := o.rmdir()
	if err != nil {
		log.Printf("(err) Failed to remove directory %s, err: %s", o.Repository.Path(), err.Error())
	}
}

func extractReference(r *Revision) string {
	if r == nil {
		return ""
	}

	ref := r.Reference

	if strings.HasPrefix(r.Reference, "refs/remotes/origin/") {
		ref = "refs/heads/" + strings.TrimPrefix(r.Reference, "refs/remotes/origin/")
	}

	return ref
}
