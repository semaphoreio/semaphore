package gitrekt

import (
	"errors"
	"log"
	"time"

	git "github.com/libgit2/git2go/v34"
)

type RemoteCallbacks struct {
	Started        time.Time
	Repository     *Repository
	AuthRetries    int
	MaxAuthRetries int
	MaxDuration    time.Duration

	HasAuthTimeouted     bool
	HasProgressTimeouted bool
}

func (o *RemoteCallbacks) toGit() git.RemoteCallbacks {
	return git.RemoteCallbacks{
		CredentialsCallback:      o.authCb,
		TransferProgressCallback: o.progressCb,
	}
}

func (o *RemoteCallbacks) progressCb(stats git.TransferProgress) error {
	current := time.Since(o.Started).Seconds()
	max := o.MaxDuration.Seconds()

	if current > max {
		log.Printf("fetch timeout %s current: %f max: %f", o.Repository.HttpURL, current, max)

		o.HasProgressTimeouted = true

		return errors.New("fetch timeout")
	}

	return nil
}

func (o *RemoteCallbacks) authCb(string, string, git.CredentialType) (cred *git.Credential, err error) {
	o.AuthRetries++

	if o.AuthRetries > o.MaxAuthRetries {
		log.Printf("Too many auth retries %s retries: %d", o.Repository.HttpURL, o.AuthRetries)

		o.HasAuthTimeouted = true

		return nil, err
	}

	cred, err = git.NewCredentialUserpassPlaintext(
		o.Repository.Credentials.Username,
		o.Repository.Credentials.Password,
	)

	return cred, err
}
