package gitrekt_test

import (
	"testing"

	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
	assert "github.com/stretchr/testify/assert"
)

//
// In the test repo on github we have two branches:
//
//   - test-base
//   - test-head
//
// Commit structure:
//
//   (c1)  ----> ( c2 - changed a.txt     )  -  test-base
//     \
//       ------> ( c3 - changed README.md )  -  test-head
//
// HeadToHead      - means comparing the diff between c2 and c3.
//                   Equivalent of `git diff test-base..test-head`.
//
// HeadToMergeBase - means comparing the diff between c1 and c3.
//                   Equivalent of `git diff test-base...test-head`.
//

func Test__Github__ListChangedFiles__HeadToHead(t *testing.T) {
	repo, err := GithubHelloWorldTestRepo()
	assert.Nil(t, err)

	base := gitrekt.Revision{Reference: "refs/remotes/origin/test-base"}
	head := gitrekt.Revision{Reference: "refs/remotes/origin/test-head"}
	comparison := gitrekt.ListChangedFilesComparisonTypeHeadToHead

	files, err := gitrekt.ListChangedFiles(repo, base, head, comparison)
	assert.Nil(t, err)

	assert.Equal(t, 2, len(files))
	assert.Equal(t, "README.md", files[0])
	assert.Equal(t, "a.txt", files[1])
}

func Test__Github__ListChangedFiles__MergeBase(t *testing.T) {
	repo, err := GithubHelloWorldTestRepo()
	assert.Nil(t, err)

	base := gitrekt.Revision{Reference: "refs/remotes/origin/test-base"}
	head := gitrekt.Revision{Reference: "refs/remotes/origin/test-head"}
	comparison := gitrekt.ListChangedFilesComparisonTypeHeadToMergeBase

	files, err := gitrekt.ListChangedFiles(repo, base, head, comparison)
	assert.Nil(t, err)

	assert.Equal(t, 1, len(files))
	assert.Equal(t, "a.txt", files[0])
}

// A commit sha can contain a ^ (carrot) at the end, indicating that the target
// is the parent commit.
//
// Example: f5e1784202c78c0c470be580c8f43ab052c94810^
func Test__Github__ListChangedFiles__WithCarrots(t *testing.T) {
	repo, err := GithubHelloWorldTestRepo()
	assert.Nil(t, err)

	base := gitrekt.Revision{CommitSha: "6ba48acec28ecc6301e73066b08a99e53ffac430"}
	head := gitrekt.Revision{CommitSha: "f70145864b843158d75c3eb6e217a4aba40853f0^"}
	comparison := gitrekt.ListChangedFilesComparisonTypeHeadToMergeBase

	files, err := gitrekt.ListChangedFiles(repo, base, head, comparison)
	assert.Nil(t, err)

	assert.Equal(t, 7, len(files))
	assert.Equal(t, "README.md", files[0])
	assert.Equal(t, "a.txt", files[1])
	assert.Equal(t, "b.txt", files[2])
	assert.Equal(t, "c.txt", files[3])
	assert.Equal(t, "d.txt", files[4])
	assert.Equal(t, "e.txt", files[5])
	assert.Equal(t, "styles.css", files[6])
}
