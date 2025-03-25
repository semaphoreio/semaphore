package gitrekt

import (
	"log"
	"time"

	git "github.com/libgit2/git2go/v34"
	"github.com/renderedtext/go-watchman"
)

type ListChangedFilesComparisonType int

const (
	ListChangedFilesComparisonTypeHeadToHead      ListChangedFilesComparisonType = 0
	ListChangedFilesComparisonTypeHeadToMergeBase ListChangedFilesComparisonType = 1
)

func ListChangedFiles(repo *Repository, base Revision, head Revision, comparison ListChangedFilesComparisonType) ([]string, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.ListChangedFiles", []string{
		repo.HttpURL,
	})

	log.Printf("ListChangedFiles Started. Repo: %s", repo.HttpURL)

	repoPath, err := UpdateOrClone(repo, nil)
	if err != nil {
		return nil, err
	}

	log.Printf("ListChangedFiles Opening Repository. Repo: %s", repo.HttpURL)

	r, err := git.OpenRepository(repoPath)
	if err != nil {
		return []string{}, err
	}
	defer r.Free()

	log.Printf("ListChangedFiles Looking Up Commits. Repo: %s", repo.HttpURL)

	//
	// Step 1: Find the commits
	//
	// HeadToHead      - means comparing the diff between c2 and c3.
	//                   Equivalent of `git diff test-base..test-head`.
	//
	// HeadToMergeBase - means comparing the diff between c1 and c3.
	//                   Equivalent of `git diff test-base...test-head`.
	//
	//

	headCommit, err := findCommit(r, head)
	if err != nil {
		return []string{}, err
	}
	defer headCommit.Free()

	baseCommit, err := findCommit(r, base)
	if err != nil {
		return []string{}, err
	}
	defer baseCommit.Free()

	if comparison == ListChangedFilesComparisonTypeHeadToMergeBase {
		mergeBase, err := r.MergeBase(
			baseCommit.AsObject().Id(),
			headCommit.AsObject().Id(),
		)

		if err != nil {
			return []string{}, err
		}

		mergeBaseCommit, err := r.LookupCommit(mergeBase)
		if err != nil {
			return []string{}, err
		}

		baseCommit = mergeBaseCommit
	}

	//
	// Step 2: Find the associated tree objects
	//

	log.Printf("ListChangedFiles Looking Up Tree Objects. Repo: %s", repo.HttpURL)

	headTree, err := headCommit.Tree()
	if err != nil {
		return []string{}, err
	}
	defer headTree.Free()

	baseTree, err := baseCommit.Tree()
	if err != nil {
		return []string{}, err
	}
	defer baseTree.Free()

	//
	// Step 3: Construct diff trees
	//
	log.Printf("ListChangedFiles Constructing Diff Trees. Repo: %s", repo.HttpURL)

	opts, err := git.DefaultDiffOptions()
	if err != nil {
		return []string{}, err
	}

	diff, err := r.DiffTreeToTree(baseTree, headTree, &opts)
	if err != nil {
		return []string{}, err
	}
	defer diff.Free()

	//
	// Step 4: Walk over the diff and collect file names
	//

	log.Printf("ListChangedFiles Walking the Diff Trees. Repo: %s", repo.HttpURL)

	lines := []string{}

	err = diff.ForEach(
		func(f git.DiffDelta, _ float64) (git.DiffForEachHunkCallback, error) {
			lines = append(lines, f.OldFile.Path)

			return nil, nil
		},
		git.DiffDetailFiles,
	)

	if err != nil {
		log.Printf("ListChangedFiles Failed. Repo: %s", repo.HttpURL)
		return []string{}, err
	}

	log.Printf("ListChangedFiles Done. Repo: %s", repo.HttpURL)
	return lines, nil
}
