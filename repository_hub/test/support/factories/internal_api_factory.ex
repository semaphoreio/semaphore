defmodule RepositoryHub.InternalApiFactory do
  alias InternalApi.Repository.{
    Repository,
    DescribeRequest,
    DescribeResponse,
    DescribeRevisionRequest,
    DescribeRevisionResponse,
    DescribeRemoteRepositoryRequest,
    DeleteRequest,
    ListRequest,
    ListResponse,
    GetFileRequest,
    GetFilesRequest,
    GetChangedFilePathsRequest,
    GetChangedFilePathsRequest,
    ClearExternalDataRequest,
    CommitRequest,
    CommitRequest,
    CommitRequest,
    GetSshKeyRequest,
    ListAccessibleRepositoriesRequest,
    ListAccessibleRepositoriesResponse,
    ListCollaboratorsRequest,
    CreateBuildStatusRequest,
    CreateBuildStatusRequest,
    CreateRequest,
    ForkRequest,
    Commit,
    Revision,
    Repository,
    File,
    CheckDeployKeyRequest,
    RegenerateDeployKeyRequest,
    CheckWebhookRequest,
    RegenerateWebhookRequest,
    VerifyWebhookSignatureRequest,
    VerifyWebhookSignatureResponse,
    UpdateRequest
  }

  def describe_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        include_private_ssh_key: false
      )

    struct(DescribeRequest, params)
  end

  def describe_response(params \\ []) do
    params =
      params
      |> with_defaults(
        repository: Keyword.get(params, :repository, repository()),
        private_ssh_key: ""
      )

    struct(DescribeResponse, params)
  end

  def describe_revision_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        revision: Keyword.get(params, :revision, revision())
      )

    struct(DescribeRevisionRequest, params)
  end

  def describe_revision_response(params \\ []) do
    params =
      params
      |> with_defaults(commit: Keyword.get(params, :commit, commit()))

    struct(DescribeRevisionResponse, params)
  end

  def describe_remote_repository_request(params \\ []) do
    params =
      params
      |> with_defaults(
        user_id: Ecto.UUID.generate(),
        integration_type: :GITHUB_OAUTH_TOKEN,
        url: "https://github.com/foo/bar"
      )

    struct(DescribeRemoteRepositoryRequest, params)
  end

  def delete_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(DeleteRequest, params)
  end

  def clear_external_data_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(ClearExternalDataRequest, params)
  end

  def list_request(params \\ []) do
    params =
      params
      |> with_defaults(project_id: Ecto.UUID.generate())

    struct(ListRequest, params)
  end

  def list_response(params \\ []) do
    params =
      params
      |> with_defaults(repositories: Keyword.get(params, :repositories, []))

    struct(ListResponse, params)
  end

  def get_file_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        commit_sha: Base.encode16(Ecto.UUID.generate()),
        path: [Ecto.UUID.generate(), Ecto.UUID.generate()] |> Path.join("")
      )

    struct(GetFileRequest, params)
  end

  def get_files_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        revision: Keyword.get(params, :revision, revision()),
        selectors: [],
        include_content: false
      )

    struct(GetFilesRequest, params)
  end

  def get_changed_file_paths_request(params \\ []) do
    params =
      params
      |> with_defaults(
        head_rev: Keyword.get(params, :head_rev, revision()),
        base_rev: Keyword.get(params, :base_rev, revision()),
        repository_id: Ecto.UUID.generate(),
        comparison_type: :HEAD_TO_MERGE_BASE
      )

    struct(GetChangedFilePathsRequest, params)
  end

  def commit_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        branch_name: "master",
        commit_message: "Introduces a new feature",
        changes: []
      )

    struct(CommitRequest, params)
  end

  def commit_request_change(params \\ []) do
    params =
      params
      |> with_defaults(
        action: :ADD_FILE,
        file: Keyword.get(params, :file, file())
      )

    struct(CommitRequest.Change, params)
  end

  def get_ssh_key_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(GetSshKeyRequest, params)
  end

  def list_accessible_repositories_request(params \\ []) do
    params =
      params
      |> with_defaults(
        user_id: Ecto.UUID.generate(),
        integration_type: :GITHUB_OAUTH_TOKEN,
        page_token: Base.encode16(Ecto.UUID.generate())
      )

    struct(ListAccessibleRepositoriesRequest, params)
  end

  def list_accessible_repositories_response(params \\ []) do
    params =
      params
      |> with_defaults(
        user_id: Ecto.UUID.generate(),
        integration_type: :GITHUB_OAUTH_TOKEN,
        page_token: Base.encode16(Ecto.UUID.generate())
      )

    struct(ListAccessibleRepositoriesResponse, params)
  end

  def list_collaborators_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        page_token: Base.encode16(Ecto.UUID.generate())
      )

    struct(ListCollaboratorsRequest, params)
  end

  def create_build_status_request(params \\ []) do
    params =
      params
      |> with_defaults(
        repository_id: Ecto.UUID.generate(),
        commit_sha: Base.encode16(Ecto.UUID.generate()),
        status: :SUCCESS,
        url: "http://url-to-ci.example.com/build/12345",
        description: "status description",
        context: Ecto.UUID.generate()
      )

    struct(CreateBuildStatusRequest, params)
  end

  def create_request(params \\ []) do
    params =
      params
      |> with_defaults(
        project_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        pipeline_file: ".semaphore/semaphore.yaml",
        repository_url: "https://github.com/foo/bar",
        only_public: false,
        commit_status: nil,
        whitelist: nil
      )

    struct(CreateRequest, params)
  end

  def fork_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(ForkRequest, params)
  end

  def check_deploy_key_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(CheckDeployKeyRequest, params)
  end

  def regenerate_deploy_key_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(RegenerateDeployKeyRequest, params)
  end

  def check_webhook_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(CheckWebhookRequest, params)
  end

  def regenerate_webhook_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(RegenerateWebhookRequest, params)
  end

  def update_request(params \\ []) do
    params =
      params
      |> Keyword.put_new(:repository_id, Ecto.UUID.generate())
      |> Keyword.put_new(:url, "https://gitlab.com/repositoryhub/semaphoreci")

    struct(UpdateRequest, params)
  end

  def verify_webhook_signature_request(params \\ []) do
    params =
      params
      |> with_defaults(repository_id: Ecto.UUID.generate())

    struct(VerifyWebhookSignatureRequest, params)
  end

  def verify_webhook_signature_response(params \\ []) do
    params =
      params
      |> with_defaults(valid: true)

    struct(VerifyWebhookSignatureResponse, params)
  end

  def revision(params \\ []) do
    params =
      params
      |> with_defaults(
        reference: Ecto.UUID.generate(),
        commit_sha: Base.encode16(Ecto.UUID.generate())
      )

    struct(Revision, params)
  end

  def commit(params \\ []) do
    params =
      params
      |> with_defaults(
        sha: Base.encode16(Ecto.UUID.generate()),
        msg: "Introduces a new feature",
        author_name: "johndoe",
        author_uuid: "1234567",
        author_avatar_url: "https://avatars.githubusercontent.com/u/1234567?v=3"
      )

    struct(Commit, params)
  end

  def repository(params \\ []) do
    params =
      params
      |> with_defaults(
        id: Ecto.UUID.generate(),
        name: "RepositoryHub",
        owner: "dummy",
        provider: "github",
        project_id: Ecto.UUID.generate(),
        pipeline_file: ".semaphore/semaphore.yml"
      )

    struct(Repository, params)
  end

  def github_repository(params \\ []) do
    params =
      params
      |> with_defaults(
        id: Ecto.UUID.generate(),
        name: "RepositoryHub",
        owner: "dummy",
        provider: "github",
        project_id: Ecto.UUID.generate(),
        pipeline_file: ".semaphore/semaphore.yml"
      )

    struct(Repository, params)
  end

  def bitbucket_repository(params \\ []) do
    params =
      params
      |> with_defaults(
        id: Ecto.UUID.generate(),
        name: "RepositoryHub",
        owner: "dummy",
        provider: "bitbucket",
        project_id: Ecto.UUID.generate(),
        pipeline_file: ".semaphore/semaphore.yml"
      )

    struct(Repository, params)
  end

  def file(params \\ []) do
    params =
      params
      |> with_defaults(
        path: "main.src",
        content: "<source code>"
      )

    struct(File, params)
  end

  defp with_defaults(params, defaults) do
    Keyword.merge(defaults, params)
  end
end
