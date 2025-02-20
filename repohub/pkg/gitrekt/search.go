package gitrekt

import (
	"log"
	"regexp"
	"time"

	doublestar "github.com/bmatcuk/doublestar"
	git "github.com/libgit2/git2go/v34"
	"github.com/renderedtext/go-watchman"
)

type SearchOptionsSelectors struct {
	Glob         string
	ContentRegex *regexp.Regexp
}

type SearchOptions struct {
	Selectors      []SearchOptionsSelectors
	IncludeContent bool
}

func Search(repo *Repository, rev Revision, options *SearchOptions) ([]*File, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "gitrekt.Search", []string{
		repo.HttpURL,
	})

	log.Printf(
		"Search Started. Repo %s, revision %+v",
		repo.HttpURL,
		rev,
	)

	repoPath, err := UpdateOrClone(repo)
	if err != nil {
		return nil, err
	}

	log.Printf(
		"Seach Opening the repository. Repo %s, revision %+v",
		repo.HttpURL,
		rev,
	)

	result := []*File{}

	r, err := git.OpenRepository(repoPath)
	if err != nil {
		return result, err
	}
	defer r.Free()

	commit, err := findCommit(r, rev)
	if err != nil {
		return result, err
	}

	tree, err := commit.Tree()
	if err != nil {
		return result, err
	}
	defer tree.Free()

	log.Printf(
		"Search Walking the Tree. Repo %s, revision %+v",
		repo.HttpURL,
		rev,
	)

	err = tree.Walk(func(dir string, e *git.TreeEntry) error {
		if e.Type == git.ObjectBlob && options.Matches(r, dir, e) {
			content := ""

			if options.IncludeContent {
				blob, _ := r.LookupBlob(e.Id)
				content = string(blob.Contents())
			}

			result = append(result, &File{
				Path:    dir + e.Name,
				Content: content,
			})
		}

		return nil
	})

	if err != nil {
		log.Printf(
			"Search Failed. Repo %s, revision %+v, err: %s",
			repo.HttpURL,
			rev,
			err.Error(),
		)

		return result, err
	}

	log.Printf(
		"Search Done. Repo %s, revision %+v",
		repo.HttpURL,
		rev,
	)

	return result, nil
}

func (o *SearchOptions) Matches(repo *git.Repository, dir string, e *git.TreeEntry) bool {
	for _, s := range o.Selectors {
		if s.Matches(repo, dir, e) {
			return true
		}
	}

	return false
}

func (s *SearchOptionsSelectors) Matches(repo *git.Repository, dir string, e *git.TreeEntry) bool {
	fullPath := dir + e.Name

	ok, err := doublestar.Match(s.Glob, fullPath)
	if err != nil {
		return false
	}

	if s.ContentRegex != nil {
		blob, _ := repo.LookupBlob(e.Id)
		content := string(blob.Contents())

		return s.ContentRegex.MatchString(content)
	}

	return ok
}
