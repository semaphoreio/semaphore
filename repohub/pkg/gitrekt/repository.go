package gitrekt

import (
	"fmt"
	"log"
	"os"
)

type Credentials struct {
	Username string
	Password string
}

type Repository struct {
	Name        string
	HttpURL     string
	Credentials *Credentials
}

type Lock struct {
	path string
}

func (r *Repository) Path() string {
	return fmt.Sprintf("/var/repos/%s", r.Name)
}

func (r *Repository) Exists() bool {
	_, err := os.Stat(r.Path())

	return !os.IsNotExist(err)
}

//
// Quarantine: This repository causes problems, and it shouldn't be touched.
//
// Examples:
//   - Timeout during clone
//   - Auth Issues during clone
//   - Manually set, high CPU, high memory
//

type QuarantineReason string

const (
	QuarantineReasonAuthTimeout  QuarantineReason = "auth-timeout"
	QuarantineReasonCloneTimeout                  = "clone-timeout"
	QuarantineReasonNotFound                      = "not-found"
	QuarantineReasonUnknown                       = "unknown"
)

func (r *Repository) QuarantinePath() string {
	return fmt.Sprintf("/var/repos/%s.quarantine", r.Name)
}

func (r *Repository) IsQuarantined() bool {
	_, err := os.Stat(r.QuarantinePath())

	return !os.IsNotExist(err)
}

func (r *Repository) PutInQuarantine(reason QuarantineReason) error {
	data := []byte(reason)

	return os.WriteFile(r.QuarantinePath(), data, 0600)
}

//
// Locking
//

func (r *Repository) LockPath() string {
	return fmt.Sprintf("/var/repos/%s.lock", r.Name)
}

func (r *Repository) IsLocked() bool {
	_, err := os.Stat(r.LockPath())

	return !os.IsNotExist(err)
}

func (r *Repository) AcquireLock() *Lock {
	if r.IsLocked() || r.IsQuarantined() {
		return nil
	}

	_, err := os.OpenFile(r.LockPath(), os.O_CREATE|os.O_RDONLY, os.FileMode(0600))

	if err != nil {
		return nil
	}

	return &Lock{
		path: r.LockPath(),
	}
}

func (r *Repository) ReleaseLock(l *Lock) {
	if l == nil {
		return
	}

	err := os.Remove(r.LockPath())

	if err != nil {
		log.Printf("Failed to remove lock file, err: %s", err.Error())
	}
}
