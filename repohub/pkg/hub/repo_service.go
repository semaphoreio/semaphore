package hub

import (
	"context"
	"log"
	"regexp"
	"strings"
	"time"

	"github.com/renderedtext/go-watchman"
	gitrekt "github.com/semaphoreio/semaphore/repohub/pkg/gitrekt"
	models "github.com/semaphoreio/semaphore/repohub/pkg/models"
	tokenstore "github.com/semaphoreio/semaphore/repohub/pkg/tokenstore"

	ia_repository "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/repository"
	ia_user "github.com/semaphoreio/semaphore/repohub/pkg/internal_api/user"

	gorm "github.com/jinzhu/gorm"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type RepoService struct {
	ia_repository.UnimplementedRepositoryServiceServer
	DB         *gorm.DB
	tokenStore *tokenstore.TokenStore
}

type Revision struct {
	CommitSha string
	Reference string
}

func NewRepoService(db *gorm.DB) *RepoService {
	return &RepoService{
		DB:         db,
		tokenStore: tokenstore.New(),
	}
}

func (s *RepoService) Describe(ctx context.Context, request *ia_repository.DescribeRequest) (*ia_repository.DescribeResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "hub.Describe", []string{
		request.RepositoryId,
	})

	log.Printf("Describe: Request %v", request)

	repo, err := s.findRepo(request.RepositoryId)
	if err != nil {
		return nil, err
	}

	return &ia_repository.DescribeResponse{
		Repository: s.serialize(repo),
	}, nil
}

func (s *RepoService) List(ctx context.Context, request *ia_repository.ListRequest) (*ia_repository.ListResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "hub.List", []string{
		request.ProjectId,
	})

	log.Printf("List: Request %v", request)

	projectID := request.ProjectId

	repos, err := models.ListRepositoriesForProject(s.DB, projectID)
	if err != nil {
		log.Printf("(err) Failed to list repositories %s %+v", projectID, err)

		return nil, status.Error(codes.Unknown, err.Error())
	}

	res := &ia_repository.ListResponse{
		Repositories: []*ia_repository.Repository{},
	}

	for i := range repos {
		r := repos[i]
		res.Repositories = append(res.Repositories, s.serialize(&r))
	}

	return res, nil
}

func (s *RepoService) GetFiles(ctx context.Context, request *ia_repository.GetFilesRequest) (*ia_repository.GetFilesResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "hub.GetFiles", []string{
		request.RepositoryId,
	})

	log.Printf(
		"GetFiles: Repo %s, Revision %+v, Selectors %+v, IncludeContent %+v",
		request.RepositoryId,
		request.Revision,
		request.Selectors,
		request.IncludeContent,
	)

	id := request.RepositoryId

	repo, err := s.findRepo(id)
	if err != nil {
		return nil, err
	}

	token, err := s.findRepoToken(repo)
	if err != nil {
		log.Printf("(err) Failed to find repository token %s %+v", id, err)

		return nil, status.Error(codes.PermissionDenied, err.Error())
	}

	options, err := s.toGitRektSearchOptions(request.Selectors, request.IncludeContent)
	if err != nil {
		log.Printf("(err) Failed to parse selectors, err %+v", err)

		return nil, status.Error(codes.InvalidArgument, err.Error())
	}

	revision := s.ensureRevision(request.Revision, repo.DefaultBranch)

	files, err := gitrekt.Search(
		s.toGitRektRepository(repo, token),
		s.toGitRektRevision(revision),
		options,
	)

	if err != nil {
		log.Printf("Error getting files for %s: %v", id, err)
		return nil, status.Error(codes.Unknown, err.Error())
	}

	response := &ia_repository.GetFilesResponse{
		Files: s.serializeFiles(files),
	}

	return response, nil
}

func (s *RepoService) Commit(ctx context.Context, request *ia_repository.CommitRequest) (*ia_repository.CommitResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "hub.Commit", []string{
		request.RepositoryId,
	})

	log.Printf(
		"Commit: Repo %s, User %s, Branch %s, CommitMessage: %s, Changes: %+v",
		request.RepositoryId,
		request.UserId,
		request.BranchName,
		request.CommitMessage,
		request.Changes,
	)

	id := request.RepositoryId

	if request.CommitMessage == "" {
		return nil, status.Error(codes.InvalidArgument, "Commit message can't be blank.")
	}

	if len(request.Changes) == 0 {
		return nil, status.Error(codes.InvalidArgument, "Commit must contain at least one change.")
	}

	repo, err := s.findRepo(id)
	if err != nil {
		return nil, err
	}

	user, err := s.findUser(request.UserId)
	if err != nil {
		log.Printf("User not found %+v", err)

		return nil, status.Error(codes.NotFound, "User not found")
	}

	token, err := s.findCommitToken(repo, user)
	if err != nil {
		log.Printf("(err) Failed to find commit token %s %+v", id, err)

		return nil, status.Error(codes.PermissionDenied, err.Error())
	}

	if token == "" {
		log.Printf("(err) Token can't be empty %v", repo)

		return nil, status.Error(codes.PermissionDenied, "Token can't be empty")
	}

	payload := gitrekt.CommitPayload{}
	payload.CommitMessage = request.CommitMessage
	payload.CommiterName = user.Name
	payload.CommiterEmail = user.Email
	payload.BranchName = request.BranchName
	payload.Changes = s.toGitRektCommitChanges(request.Changes)

	revision, err := gitrekt.Commit(
		s.toGitRektRepository(repo, token),
		payload,
	)

	if err != nil {
		log.Printf("Error while commiting. Repo %s, Err %+v", request.RepositoryId, err)

		return nil, status.Error(codes.Unknown, "Error while commiting to repository")
	}

	response := &ia_repository.CommitResponse{
		Revision: &ia_repository.Revision{
			CommitSha: revision.CommitSha,
			Reference: revision.Reference,
		},
	}

	return response, nil
}

func (s *RepoService) GetChangedFilePaths(ctx context.Context, request *ia_repository.GetChangedFilePathsRequest) (*ia_repository.GetChangedFilePathsResponse, error) {
	defer watchman.BenchmarkWithTags(time.Now(), "hub.GetChangedFilePaths", []string{
		request.RepositoryId,
	})

	log.Printf(
		"GetChangedFilePaths: Repo %s, Head %v, Base %v",
		request.RepositoryId,
		request.HeadRev,
		request.BaseRev,
	)

	id := request.RepositoryId

	repo, err := s.findRepo(id)
	if err != nil {
		return nil, err
	}

	token, err := s.findRepoToken(repo)
	if err != nil {
		log.Printf("(err) Failed to find repository token %s %+v", id, err)

		return nil, status.Error(codes.PermissionDenied, err.Error())
	}

	baseRev := s.ensureRevision(request.BaseRev, "")
	headRev := s.ensureRevision(request.HeadRev, "")

	files, err := gitrekt.ListChangedFiles(
		s.toGitRektRepository(repo, token),
		s.toGitRektRevision(baseRev),
		s.toGitRektRevision(headRev),
		s.toGitRektComparisonType(request.ComparisonType),
	)
	if err != nil {
		log.Printf("GetChangedFilePaths: (err) %+v", err)
		return nil, err
	}

	return &ia_repository.GetChangedFilePathsResponse{
		ChangedFilePaths: files,
	}, nil
}

//
// Internals
//

func (s *RepoService) findRepo(id string) (*models.Repository, error) {
	repo, err := models.FindRepository(s.DB, id)

	if err != nil {
		log.Printf("(err) Failed to find repository %s %+v", id, err)

		if gorm.IsRecordNotFoundError(err) {
			return nil, status.Error(codes.NotFound, "Repository not found")
		}

		log.Printf("Unexpected error while looking up repository %s %+v", id, err)
		return nil, status.Errorf(codes.Unknown, "Error while looking up repository")
	}

	return repo, nil
}

func (s *RepoService) findCommitToken(r *models.Repository, u *ia_user.DescribeResponse) (string, error) {
	return s.tokenStore.FindCommitToken(r, u.UserId)
}

func (s *RepoService) findRepoToken(r *models.Repository) (string, error) {
	return s.tokenStore.FindRepoToken(r)
}

func (s *RepoService) findUser(id string) (*ia_user.DescribeResponse, error) {
	return s.tokenStore.FindUser(id)
}

//
// Serialization
//

func (s *RepoService) serialize(repo *models.Repository) *ia_repository.Repository {
	return &ia_repository.Repository{
		Id:           repo.ID.String(),
		Name:         repo.Name,
		Owner:        repo.Owner,
		Provider:     repo.Provider,
		Url:          repo.URL,
		PipelineFile: repo.PipelineFile,
	}
}

func (s *RepoService) serializeFiles(files []*gitrekt.File) []*ia_repository.File {
	result := []*ia_repository.File{}

	for _, f := range files {
		result = append(result, &ia_repository.File{
			Path:    f.Path,
			Content: f.Content,
		})
	}

	return result
}

//
// GitRekt utilities
//

func (s *RepoService) toGitRektSearchOptions(selectors []*ia_repository.GetFilesRequest_Selector, includeContent bool) (*gitrekt.SearchOptions, error) {
	options := &gitrekt.SearchOptions{}

	options.IncludeContent = includeContent

	for _, s := range selectors {
		selector := gitrekt.SearchOptionsSelectors{Glob: s.Glob}

		if s.ContentRegex != "" {
			reg, err := regexp.Compile(s.ContentRegex)

			if err != nil {
				return nil, err
			}

			selector.ContentRegex = reg
		}

		options.Selectors = append(options.Selectors, selector)
	}

	return options, nil
}

func (s *RepoService) ensureRevision(r *ia_repository.Revision, defaultBranch string) *Revision {
	ref := ""
	sha := ""

	if defaultBranch != "" {
		ref = "refs/heads/" + defaultBranch
	}

	if r != nil && r.Reference != "" {
		ref = r.Reference
	}

	if r != nil && r.CommitSha != "" {
		sha = r.CommitSha
	}

	return &Revision{
		CommitSha: sha,
		Reference: ref,
	}
}

func (s *RepoService) toGitRektRevision(r *Revision) gitrekt.Revision {
	ref := r.Reference

	if strings.HasPrefix(r.Reference, "refs/heads/") {
		ref = "refs/remotes/origin/" + strings.TrimPrefix(r.Reference, "refs/heads/")
	}

	return gitrekt.Revision{
		Reference: ref,
		CommitSha: r.CommitSha,
	}
}

func (s *RepoService) toGitRektCommitChanges(changes []*ia_repository.CommitRequest_Change) []gitrekt.CommitPayloadChange {
	result := []gitrekt.CommitPayloadChange{}

	for _, c := range changes {
		var action gitrekt.CommitPayloadAction

		switch c.Action {
		case ia_repository.CommitRequest_Change_ADD_FILE:
			action = gitrekt.CommitPayloadAddFile
		case ia_repository.CommitRequest_Change_MODIFY_FILE:
			action = gitrekt.CommitPayloadModifyFile
		case ia_repository.CommitRequest_Change_DELETE_FILE:
			action = gitrekt.CommitPayloadDeleteFile
		}

		result = append(result, gitrekt.CommitPayloadChange{
			Content: c.File.Content,
			Path:    c.File.Path,
			Action:  action,
		})
	}

	return result
}

func (s *RepoService) toGitRektComparisonType(t ia_repository.GetChangedFilePathsRequest_ComparisonType) gitrekt.ListChangedFilesComparisonType {
	switch t {
	case ia_repository.GetChangedFilePathsRequest_HEAD_TO_HEAD:
		return gitrekt.ListChangedFilesComparisonTypeHeadToHead

	case ia_repository.GetChangedFilePathsRequest_HEAD_TO_MERGE_BASE:
		return gitrekt.ListChangedFilesComparisonTypeHeadToMergeBase

	default:
		panic("Unknown comparison type")
	}
}

func (s *RepoService) toGitRektRepository(r *models.Repository, token string) *gitrekt.Repository {
	return tokenstore.ToGitRektRepository(r, token)
}
