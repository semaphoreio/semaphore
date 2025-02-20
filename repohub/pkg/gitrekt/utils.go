package gitrekt

import (
	"fmt"

	git "github.com/libgit2/git2go/v34"
)

func findCommit(repo *git.Repository, rev Revision) (*git.Commit, error) {
	if rev.CommitSha != "" {
		obj, err := repo.RevparseSingle(rev.CommitSha)
		if err != nil {
			return nil, err
		}

		return obj.AsCommit()
	}

	if rev.Reference != "" {
		reference, err := repo.References.Lookup(rev.Reference)
		if err != nil {
			return nil, err
		}

		oid := reference.Target()

		return repo.LookupCommit(oid)
	}

	return nil, fmt.Errorf("Invalid revision")
}
