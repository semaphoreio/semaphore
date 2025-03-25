package gitrekt

import (
	"fmt"
	"log"
	"time"

	git "github.com/libgit2/git2go/v34"
	"github.com/renderedtext/go-watchman"
)

func check(err error, message string) {
	if err != nil {
		panic(fmt.Errorf("%s. err: %+v", message, err))
	}
}

type CommitPayloadAction int

const (
	CommitPayloadAddFile    = 1
	CommitPayloadModifyFile = 2
	CommitPayloadDeleteFile = 3
)

type CommitPayloadChange struct {
	Path    string
	Content string
	Action  CommitPayloadAction
}

type CommitPayload struct {
	CommitMessage string
	CommiterName  string
	CommiterEmail string
	Changes       []CommitPayloadChange
	BranchName    string
}

func Commit(repo *Repository, payload CommitPayload) (rev *Revision, err error) {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.commit", []string{
		repo.HttpURL,
	})

	defer func() {
		if r := recover(); r != nil {
			err = r.(error)
		}
	}()

	op := NewCommitOperation(repo, payload)

	return op.Run()
}

//
// Operation implementation
//

type CommitOperation struct {
	Repository *Repository
	Payload    CommitPayload

	localRefName  string
	remoteRefName string
	signiture     *git.Signature
}

func NewCommitOperation(repo *Repository, payload CommitPayload) *CommitOperation {
	return &CommitOperation{
		Repository: repo,
		Payload:    payload,

		localRefName:  fmt.Sprintf("refs/heads/branch-for-commit-%d", time.Now().UnixNano()),
		remoteRefName: fmt.Sprintf("refs/heads/%s", payload.BranchName),

		signiture: &git.Signature{
			Name:  payload.CommiterName,
			Email: payload.CommiterEmail,
			When:  time.Now(),
		},
	}
}

func (op *CommitOperation) Validate() error {
	if op.Payload.BranchName == "" {
		return fmt.Errorf("Branch name can't be blank")
	}

	return nil
}

func (op *CommitOperation) Run() (*Revision, error) {
	log.Printf(
		"Commiting to repo %s, branch %s",
		op.Repository.HttpURL,
		op.Payload.BranchName,
	)

	err := op.Validate()
	check(err, "Invalid parameters")

	repoPath, err := UpdateOrClone(op.Repository, nil)
	check(err, "Failed to clone repository")

	r, err := git.OpenRepository(repoPath)
	check(err, "Failed to open repository")
	defer r.Free()

	oid, err := op.createCommit(r)
	check(err, "Failed to create commit")

	err = op.push(r)
	check(err, "Failed to push")

	sha := oid.String()

	log.Printf(
		"Commiting finished for ref: %s, sha %s. Repo %s.",
		op.remoteRefName,
		sha,
		op.Repository.HttpURL,
	)

	return &Revision{CommitSha: sha, Reference: op.remoteRefName}, err
}

func (op *CommitOperation) push(r *git.Repository) error {
	log.Printf(
		"Pushing local %s to remote %s. Repo %s.",
		op.localRefName,
		op.remoteRefName,
		op.Repository.HttpURL,
	)

	origin, err := r.Remotes.Lookup("origin")
	check(err, "Failed to lookup origin remote")

	refspec := op.localRefName + ":" + op.remoteRefName

	remoteCallbacks := RemoteCallbacks{
		Started:        time.Now(),
		Repository:     op.Repository,
		MaxAuthRetries: 10,
		MaxDuration:    2 * time.Minute,
	}

	pushOptions := git.PushOptions{
		RemoteCallbacks: remoteCallbacks.toGit(),
	}

	err = origin.Push([]string{refspec}, &pushOptions)
	if err != nil {
		return err
	}

	if remoteCallbacks.HasAuthTimeouted {
		log.Printf("Auth timeout. Repo %s.", op.Repository.HttpURL)

		return fmt.Errorf("auth failed for repository %s", op.Repository.HttpURL)
	}

	if remoteCallbacks.HasProgressTimeouted {
		log.Printf("Progress timeout. Repo %s.", op.Repository.HttpURL)

		return fmt.Errorf("Timeout while fetching repository %s", op.Repository.HttpURL)
	}

	return nil
}

func (op *CommitOperation) createCommit(r *git.Repository) (*git.Oid, error) {
	parentCommit, err := op.findParentCommit(r)
	check(err, "Failed to lookup parent commit")

	index, err := op.createIndex(r, op.Payload, parentCommit)
	check(err, "Failed to create index from payload.")
	defer index.Free()

	treeId, err := index.WriteTreeTo(r)
	check(err, "Failed to write tree")

	tree, err := r.LookupTree(treeId)
	check(err, "Failed to lookup tree")

	_ = index.Write()

	return r.CreateCommit(
		op.localRefName,
		op.signiture,
		op.signiture,
		op.Payload.CommitMessage,
		tree,
		parentCommit,
	)
}

func (op *CommitOperation) findParentCommit(r *git.Repository) (*git.Commit, error) {
	refName := "refs/remotes/origin/" + op.Payload.BranchName
	ref, err := r.References.Lookup(refName)

	if err != nil {
		log.Printf("Failed to find remote branch %s. Repo %s.", refName, op.Repository.HttpURL)
		log.Printf("Looking up master branch. Repo %s.", op.Repository.HttpURL)

		ref, err = r.References.Lookup("refs/remotes/origin/master")

		if err != nil {
			log.Printf("Failed to find master branch. Repo %s.", op.Repository.HttpURL)
			log.Printf("Looking up main branch. Repo %s.", op.Repository.HttpURL)

			ref, err = r.References.Lookup("refs/remotes/origin/main")

			if err != nil {
				log.Printf("Failed to find main branch. Repo %s.", op.Repository.HttpURL)

				return nil, err
			}
		}
	}

	commit, err := r.LookupCommit(ref.Target())
	if err != nil {
		return nil, err
	}

	return commit, nil
}

func (op *CommitOperation) createIndex(repo *git.Repository, payload CommitPayload, parentCommit *git.Commit) (*git.Index, error) {
	index, err := git.NewIndex()
	if err != nil {
		log.Printf(
			"(err) Failed to create a new index for repo %s, branch %s, err %+v",
			op.Repository.HttpURL,
			op.Payload.BranchName,
			err,
		)

		return nil, err
	}

	parentTree, err := parentCommit.Tree()
	if err != nil {
		log.Printf(
			"(err) Failed to find the parent commit's tree repo %s, branch %s, err %+v",
			op.Repository.HttpURL,
			op.Payload.BranchName,
			err,
		)

		return nil, err
	}

	err = index.ReadTree(parentTree)
	if err != nil {
		log.Printf(
			"(err) Failed to populate index for repo %s, branch %s, err %+v",
			op.Repository.HttpURL,
			op.Payload.BranchName,
			err,
		)

		return nil, err
	}

	for _, change := range payload.Changes {
		switch change.Action {
		case CommitPayloadAddFile, CommitPayloadModifyFile:
			log.Printf(
				"Applying Chages to repo %s, branch %s. Adding %s",
				op.Repository.HttpURL,
				op.Payload.BranchName,
				change.Path,
			)

			oid, err := repo.CreateBlobFromBuffer([]byte(change.Content))
			if err != nil {
				return nil, err
			}

			ie := git.IndexEntry{
				Mode: git.FilemodeBlob,
				Id:   oid,
				Path: change.Path,
			}

			err = index.Add(&ie)
			if err != nil {
				return nil, err
			}

		case CommitPayloadDeleteFile:
			log.Printf(
				"Applying Chages to repo %s, branch %s. Delete File: %s",
				op.Repository.HttpURL,
				op.Payload.BranchName,
				change.Path,
			)

			err = index.RemoveByPath(change.Path)
			if err != nil {
				return nil, err
			}
		}
	}

	return index, nil
}
