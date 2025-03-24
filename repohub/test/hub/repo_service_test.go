package hub_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	ia_repository "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository"

	support "github.com/semaphoreio/semaphore/repohub/test/support"
	assert "github.com/stretchr/testify/assert"
)

func Test__Describe(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.DescribeRequest{
		RepositoryId: repo.ID.String(),
	}

	res, err := client.Describe(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, res.Repository.Id, repo.ID.String())
	assert.Equal(t, res.Repository.Name, repo.Name)
	assert.Equal(t, res.Repository.Owner, repo.Owner)
	assert.Equal(t, res.Repository.Provider, repo.Provider)
	assert.Equal(t, res.Repository.Url, repo.URL)
	assert.Equal(t, res.Repository.PipelineFile, repo.PipelineFile)
}

func Test__List(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.ListRequest{
		ProjectId: repo.ProjectID.String(),
	}

	res, err := client.List(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, res.Repositories[0].Id, repo.ID.String())
	assert.Equal(t, res.Repositories[0].Name, repo.Name)
	assert.Equal(t, res.Repositories[0].Owner, repo.Owner)
	assert.Equal(t, res.Repositories[0].Provider, repo.Provider)
	assert.Equal(t, res.Repositories[0].Url, repo.URL)
	assert.Equal(t, res.Repositories[0].PipelineFile, repo.PipelineFile)
}

func Test__GetChangedFilePaths__HeadToHead(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetChangedFilePathsRequest{
		BaseRev:        &ia_repository.Revision{Reference: "refs/heads/test-base"},
		HeadRev:        &ia_repository.Revision{Reference: "refs/heads/test-head"},
		RepositoryId:   repo.ID.String(),
		ComparisonType: ia_repository.GetChangedFilePathsRequest_HEAD_TO_HEAD,
	}

	res, err := client.GetChangedFilePaths(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, 2, len(res.ChangedFilePaths))
	assert.Equal(t, "README.md", res.ChangedFilePaths[0])
	assert.Equal(t, "a.txt", res.ChangedFilePaths[1])
}

func Test__GetChangedFilePaths__HeadToMergeBase(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetChangedFilePathsRequest{
		BaseRev:        &ia_repository.Revision{Reference: "refs/heads/test-base"},
		HeadRev:        &ia_repository.Revision{Reference: "refs/heads/test-head"},
		RepositoryId:   repo.ID.String(),
		ComparisonType: ia_repository.GetChangedFilePathsRequest_HEAD_TO_MERGE_BASE,
	}

	res, err := client.GetChangedFilePaths(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, 1, len(res.ChangedFilePaths))
	assert.Equal(t, "a.txt", res.ChangedFilePaths[0])
}

func Test__Commit__ToExistingBranch(t *testing.T) {
	support.PurgeDB()

	branchName := "test-commit-static"

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.CommitRequest{
		RepositoryId:  repo.ID.String(),
		UserId:        support.FakeUserServiceUserID,
		BranchName:    branchName,
		CommitMessage: "Hello!",

		Changes: []*ia_repository.CommitRequest_Change{
			&ia_repository.CommitRequest_Change{
				File: &ia_repository.File{
					Content: fmt.Sprintf("Hello %d", time.Now().Unix()),
					Path:    fmt.Sprintf("commit_test_%d.txt", time.Now().Unix()),
				},
				Action: ia_repository.CommitRequest_Change_ADD_FILE,
			},
		},
	}

	res, err := client.Commit(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, "refs/heads/"+branchName, res.Revision.Reference)
	assert.NotEqual(t, "", res.Revision.CommitSha)
}

func Test__Commit__ToNewBranch(t *testing.T) {
	support.PurgeDB()

	branchName := fmt.Sprintf("test-commit-%d", time.Now().UnixNano())

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.CommitRequest{
		RepositoryId:  repo.ID.String(),
		UserId:        support.FakeUserServiceUserID,
		BranchName:    branchName,
		CommitMessage: "Hello!",

		Changes: []*ia_repository.CommitRequest_Change{
			&ia_repository.CommitRequest_Change{
				File: &ia_repository.File{
					Content: fmt.Sprintf("Hello %d", time.Now().Unix()),
					Path:    "commit_test.txt",
				},
				Action: ia_repository.CommitRequest_Change_ADD_FILE,
			},
		},
	}

	res, err := client.Commit(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, res.Revision.Reference, "refs/heads/"+branchName)
	assert.NotEqual(t, res.Revision.CommitSha, "")
}

func Test__GetFiles__WithoutContent(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "f70145864b843158d75c3eb6e217a4aba40853f0",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob: "*.txt",
			},
		},
		IncludeContent: false,
	}

	res, err := client.GetFiles(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, 5, len(res.Files))

	assert.Equal(t, res.Files[0].Path, "a.txt")
	assert.Equal(t, res.Files[0].Content, "")

	assert.Equal(t, res.Files[1].Path, "b.txt")
	assert.Equal(t, res.Files[1].Content, "")

	assert.Equal(t, res.Files[2].Path, "c.txt")
	assert.Equal(t, res.Files[2].Content, "")

	assert.Equal(t, res.Files[3].Path, "d.txt")
	assert.Equal(t, res.Files[3].Content, "")

	assert.Equal(t, res.Files[4].Path, "e.txt")
	assert.Equal(t, res.Files[4].Content, "")
}

func Test__GetFiles__WithContent(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "f70145864b843158d75c3eb6e217a4aba40853f0",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob: "*.txt",
			},
		},
		IncludeContent: true,
	}

	res, err := client.GetFiles(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, 5, len(res.Files))

	assert.Equal(t, "a.txt", res.Files[0].Path)
	assert.Equal(t, "Hello\n", res.Files[0].Content)

	assert.Equal(t, "b.txt", res.Files[1].Path)
	assert.Equal(t, "Hello\n", res.Files[1].Content)

	assert.Equal(t, "c.txt", res.Files[2].Path)
	assert.Equal(t, "Hello\n", res.Files[2].Content)

	assert.Equal(t, "d.txt", res.Files[3].Path)
	assert.Equal(t, "Hello\n", res.Files[3].Content)

	assert.Equal(t, "e.txt", res.Files[4].Path)
	assert.Equal(t, "Hello\n", res.Files[4].Content)
}

func Test__GetFiles__AdvancedGlobing(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "5f4138948b165a491b7034d3e95ce023a1a098c5",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob: "scripts/**/*.sh",
			},
		},
		IncludeContent: true,
	}

	res, err := client.GetFiles(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, 3, len(res.Files))

	assert.Equal(t, "scripts/a.sh", res.Files[0].Path)
	assert.Equal(t, "A\n", res.Files[0].Content)

	assert.Equal(t, "scripts/b.sh", res.Files[1].Path)
	assert.Equal(t, "B\n", res.Files[1].Content)

	assert.Equal(t, "scripts/deploy/a.sh", res.Files[2].Path)
	assert.Equal(t, "AAA !\n\nA is the best!\n", res.Files[2].Content)
}

func Test__GetFiles__MultipleSelectors(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "5f4138948b165a491b7034d3e95ce023a1a098c5",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob: "scripts/**/*.sh",
			},
			&ia_repository.GetFilesRequest_Selector{
				Glob: "README.md",
			},
		},
		IncludeContent: true,
	}

	res, err := client.GetFiles(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, len(res.Files), 4)

	assert.Equal(t, res.Files[0].Path, "README.md")
	assert.Equal(t, res.Files[1].Path, "scripts/a.sh")
	assert.Equal(t, res.Files[2].Path, "scripts/b.sh")
	assert.Equal(t, res.Files[3].Path, "scripts/deploy/a.sh")
}

func Test__GetFiles__ContentRegex(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "5f4138948b165a491b7034d3e95ce023a1a098c5",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob:         "scripts/**/*.sh",
				ContentRegex: ".*A is the best.*",
			},
		},
		IncludeContent: true,
	}

	res, err := client.GetFiles(context.Background(), &req)
	assert.Nil(t, err)

	assert.Equal(t, len(res.Files), 1)

	assert.Equal(t, res.Files[0].Path, "scripts/deploy/a.sh")
	assert.Equal(t, res.Files[0].Content, "AAA !\n\nA is the best!\n")
}

func Test__GetFiles__WithReferenceThatDoesExist(t *testing.T) {
	support.PurgeDB()

	repo := support.CreateRepository()
	client := ia_repository.NewRepositoryServiceClient(testConn)

	req := ia_repository.GetFilesRequest{
		RepositoryId: repo.ID.String(),

		Revision: &ia_repository.Revision{
			CommitSha: "5f4138948b165a491b7034d3e95ce023a1a098c5",
			Reference: "refs/heads/does-not-exist",
		},

		Selectors: []*ia_repository.GetFilesRequest_Selector{
			&ia_repository.GetFilesRequest_Selector{
				Glob: "*.txt",
			},
		},
	}

	_, err := client.GetFiles(context.Background(), &req)
	assert.ErrorContains(t, err, "(err) Fetch repo")
}
