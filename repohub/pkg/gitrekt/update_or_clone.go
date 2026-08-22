package gitrekt

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"os/exec"
	"strings"
	"syscall"
	"time"

	"github.com/renderedtext/go-watchman"
)

func UpdateOrClone(repo *Repository, revision *Revision) (string, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.UpdateOrClone", []string{repo.HttpURL})

	reference := extractReference(revision)

	op := NewUpdateOrCloneOperation(repo, reference)
	err := op.Run()

	log.Printf("UpdateOrClone took %f seconds", op.Duration())

	return op.Repository.Path(), err
}

//
// Internals
//

type UpdateOrCloneOperation struct {
	Repository *Repository
	Reference  string
	Started    time.Time
	Finished   time.Time
}

func NewUpdateOrCloneOperation(repo *Repository, reference string) *UpdateOrCloneOperation {
	return &UpdateOrCloneOperation{Repository: repo, Reference: reference}
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

	remoteURL, err := url.Parse(o.Repository.HttpURL)
	if err != nil {
		return fmt.Errorf("failed to parse remote URL %s: %w", o.Repository.HttpURL, err)
	}

	// #nosec G204
	updateCmd := exec.CommandContext(ctx, "git", "remote", "set-url", "origin", remoteURL.String())
	updateCmd.Dir = o.Repository.Path()
	out, err := updateCmd.CombinedOutput()
	if err != nil {
		log.Printf("failed to update remote URL for %s, out: %s", o.Repository.HttpURL, string(out))
	}

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

	out, err = cmd.CombinedOutput()
	if err != nil {
		log.Printf("(err) Fetch repo %s, out: %s", o.Repository.HttpURL, string(out))
		return o.parseError(out, err)
	}

	return nil
}

func (o *UpdateOrCloneOperation) Clone() error {
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
		return &NotFoundError{Output: string(output)}
	}

	if strings.Contains(string(output), "fatal: Authentication failed") {
		return &AuthFailedError{Output: string(output)}
	}

	if exiterr, ok := err.(*exec.ExitError); ok {
		if status, ok := exiterr.Sys().(syscall.WaitStatus); ok {
			if status.ExitStatus() == -1 && strings.Contains(err.Error(), "killed") {
				return &TimeoutError{Output: string(output)}
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
