defmodule InternalApi.Repository.Collaborator.Permission do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :ADMIN, 0
  field :WRITE, 1
  field :READ, 2
end

defmodule InternalApi.Repository.CreateBuildStatusRequest.Status do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :SUCCESS, 0
  field :PENDING, 1
  field :FAILURE, 2
  field :STOPPED, 3
end

defmodule InternalApi.Repository.CreateBuildStatusResponse.Code do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :CUSTOM, 0
  field :OK, 1
  field :VALIDATION_FAILED, 2
  field :SERVICE_ERROR, 3
  field :UNAUTHORIZED, 4
  field :ACCOUNT_SUSPENDED, 5
end

defmodule InternalApi.Repository.GetChangedFilePathsRequest.ComparisonType do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :HEAD_TO_MERGE_BASE, 0
  field :HEAD_TO_HEAD, 1
end

defmodule InternalApi.Repository.CommitRequest.Change.Action do
  @moduledoc false

  use Protobuf, enum: true, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :ADD_FILE, 0
  field :MODIFY_FILE, 1
  field :DELETE_FILE, 2
end

defmodule InternalApi.Repository.DescribeRevisionRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :revision, 2, type: InternalApi.Repository.Revision
end

defmodule InternalApi.Repository.DescribeRevisionResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :commit, 1, type: InternalApi.Repository.Commit
end

defmodule InternalApi.Repository.Commit do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :sha, 1, type: :string
  field :msg, 2, type: :string
  field :author_name, 3, type: :string, json_name: "authorName"
  field :author_uuid, 4, type: :string, json_name: "authorUuid"
  field :author_avatar_url, 5, type: :string, json_name: "authorAvatarUrl"
end

defmodule InternalApi.Repository.DeployKey do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :title, 1, type: :string
  field :fingerprint, 2, type: :string
  field :created_at, 3, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :public_key, 4, type: :string, json_name: "publicKey"
end

defmodule InternalApi.Repository.DescribeRemoteRepositoryRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"

  field :integration_type, 2,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :url, 3, type: :string
end

defmodule InternalApi.Repository.DescribeRemoteRepositoryResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :remote_repository, 1,
    type: InternalApi.Repository.RemoteRepository,
    json_name: "remoteRepository"
end

defmodule InternalApi.Repository.CheckDeployKeyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.CheckDeployKeyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :deploy_key, 1, type: InternalApi.Repository.DeployKey, json_name: "deployKey"
end

defmodule InternalApi.Repository.RegenerateDeployKeyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.RegenerateDeployKeyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :deploy_key, 1, type: InternalApi.Repository.DeployKey, json_name: "deployKey"
end

defmodule InternalApi.Repository.Webhook do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :url, 1, type: :string
end

defmodule InternalApi.Repository.CheckWebhookRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.CheckWebhookResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :webhook, 1, type: InternalApi.Repository.Webhook
end

defmodule InternalApi.Repository.RegenerateWebhookRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.RegenerateWebhookResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :webhook, 1, type: InternalApi.Repository.Webhook
end

defmodule InternalApi.Repository.ForkRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"

  field :integration_type, 2,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :url, 3, type: :string
end

defmodule InternalApi.Repository.ForkResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :remote_repository, 1,
    type: InternalApi.Repository.RemoteRepository,
    json_name: "remoteRepository"
end

defmodule InternalApi.Repository.ListAccessibleRepositoriesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :user_id, 1, type: :string, json_name: "userId"

  field :integration_type, 2,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :page_token, 3, type: :string, json_name: "pageToken"
  field :only_public, 4, type: :bool, json_name: "onlyPublic"
end

defmodule InternalApi.Repository.ListAccessibleRepositoriesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repositories, 1, repeated: true, type: InternalApi.Repository.RemoteRepository
  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Repository.ListCollaboratorsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :page_token, 2, type: :string, json_name: "pageToken"
end

defmodule InternalApi.Repository.ListCollaboratorsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :collaborators, 1, repeated: true, type: InternalApi.Repository.Collaborator
  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Repository.Collaborator do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :login, 2, type: :string
  field :permission, 3, type: InternalApi.Repository.Collaborator.Permission, enum: true
end

defmodule InternalApi.Repository.CreateBuildStatusRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :commit_sha, 2, type: :string, json_name: "commitSha"
  field :status, 3, type: InternalApi.Repository.CreateBuildStatusRequest.Status, enum: true
  field :url, 4, type: :string
  field :description, 5, type: :string
  field :context, 6, type: :string
end

defmodule InternalApi.Repository.CreateBuildStatusResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :code, 1, type: InternalApi.Repository.CreateBuildStatusResponse.Code, enum: true
end

defmodule InternalApi.Repository.DescribeRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :include_private_ssh_key, 2, type: :bool, json_name: "includePrivateSshKey"
end

defmodule InternalApi.Repository.DescribeResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository, 1, type: InternalApi.Repository.Repository
  field :private_ssh_key, 2, type: :string, json_name: "privateSshKey"
end

defmodule InternalApi.Repository.DescribeManyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_ids, 1, repeated: true, type: :string, json_name: "repositoryIds"
  field :project_ids, 2, repeated: true, type: :string, json_name: "projectIds"
end

defmodule InternalApi.Repository.DescribeManyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repositories, 1, repeated: true, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.ListRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :project_id, 1, type: :string, json_name: "projectId"
end

defmodule InternalApi.Repository.ListResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repositories, 1, repeated: true, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.Repository do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :owner, 3, type: :string
  field :private, 4, type: :bool
  field :provider, 5, type: :string
  field :url, 6, type: :string
  field :project_id, 7, type: :string, json_name: "projectId"
  field :pipeline_file, 8, type: :string, json_name: "pipelineFile"

  field :integration_type, 9,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :commit_status, 10,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status,
    json_name: "commitStatus"

  field :whitelist, 11, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist
  field :hook_id, 12, type: :string, json_name: "hookId"
  field :default_branch, 13, type: :string, json_name: "defaultBranch"
  field :connected, 14, type: :bool
end

defmodule InternalApi.Repository.RemoteRepository do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :description, 3, type: :string
  field :url, 4, type: :string
  field :full_name, 5, type: :string, json_name: "fullName"
  field :addable, 6, type: :bool
  field :reason, 7, type: :string
end

defmodule InternalApi.Repository.Revision do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :commit_sha, 1, type: :string, json_name: "commitSha"
  field :reference, 2, type: :string
end

defmodule InternalApi.Repository.GetFileRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :commit_sha, 2, type: :string, json_name: "commitSha"
  field :path, 3, type: :string
end

defmodule InternalApi.Repository.GetFileResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :file, 1, type: InternalApi.Repository.File
end

defmodule InternalApi.Repository.GetFilesRequest.Selector do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :glob, 1, type: :string
  field :content_regex, 2, type: :string, json_name: "contentRegex"
end

defmodule InternalApi.Repository.GetFilesRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :revision, 2, type: InternalApi.Repository.Revision
  field :selectors, 3, repeated: true, type: InternalApi.Repository.GetFilesRequest.Selector
  field :include_content, 4, type: :bool, json_name: "includeContent"
end

defmodule InternalApi.Repository.GetFilesResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :files, 1, repeated: true, type: InternalApi.Repository.File
end

defmodule InternalApi.Repository.File do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :path, 1, type: :string
  field :content, 2, type: :string
end

defmodule InternalApi.Repository.GetChangedFilePathsRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :head_rev, 1, type: InternalApi.Repository.Revision, json_name: "headRev"
  field :base_rev, 2, type: InternalApi.Repository.Revision, json_name: "baseRev"
  field :repository_id, 3, type: :string, json_name: "repositoryId"

  field :comparison_type, 4,
    type: InternalApi.Repository.GetChangedFilePathsRequest.ComparisonType,
    json_name: "comparisonType",
    enum: true
end

defmodule InternalApi.Repository.GetChangedFilePathsResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :changed_file_paths, 1, repeated: true, type: :string, json_name: "changedFilePaths"
end

defmodule InternalApi.Repository.GetSshKeyRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.GetSshKeyResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :private_ssh_key, 1, type: :string, json_name: "privateSshKey"
end

defmodule InternalApi.Repository.CommitRequest.Change do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :action, 1, type: InternalApi.Repository.CommitRequest.Change.Action, enum: true
  field :file, 2, type: InternalApi.Repository.File
end

defmodule InternalApi.Repository.CommitRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :branch_name, 3, type: :string, json_name: "branchName"
  field :commit_message, 4, type: :string, json_name: "commitMessage"
  field :changes, 5, repeated: true, type: InternalApi.Repository.CommitRequest.Change
end

defmodule InternalApi.Repository.CommitResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :revision, 1, type: InternalApi.Repository.Revision
end

defmodule InternalApi.Repository.CreateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :project_id, 1, type: :string, json_name: "projectId"
  field :user_id, 2, type: :string, json_name: "userId"
  field :pipeline_file, 3, type: :string, json_name: "pipelineFile"
  field :repository_url, 4, type: :string, json_name: "repositoryUrl"
  field :request_id, 5, type: :string, json_name: "requestId"
  field :only_public, 6, type: :bool, json_name: "onlyPublic"

  field :integration_type, 7,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :commit_status, 8,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status,
    json_name: "commitStatus"

  field :whitelist, 9, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist
  field :default_branch, 10, type: :string, json_name: "defaultBranch"
end

defmodule InternalApi.Repository.CreateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository, 1, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.DeleteRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.DeleteResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository, 1, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.UpdateRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
  field :url, 2, type: :string
  field :pipeline_file, 3, type: :string, json_name: "pipelineFile"

  field :integration_type, 4,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true

  field :commit_status, 5,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status,
    json_name: "commitStatus"

  field :whitelist, 6, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist
  field :default_branch, 7, type: :string, json_name: "defaultBranch"
end

defmodule InternalApi.Repository.UpdateResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository, 1, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.RemoteRepositoryChanged do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :remote_id, 1, type: :string, json_name: "remoteId"
  field :repository_id, 2, type: :string, json_name: "repositoryId"
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Repository.VerifyWebhookSignatureRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :repository_id, 2, type: :string, json_name: "repositoryId"
  field :payload, 3, type: :string
  field :signature, 4, type: :string
end

defmodule InternalApi.Repository.VerifyWebhookSignatureResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :valid, 1, type: :bool
end

defmodule InternalApi.Repository.ClearExternalDataRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.ClearExternalDataResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository, 1, type: InternalApi.Repository.Repository
end

defmodule InternalApi.Repository.RegenerateWebhookSecretRequest do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :repository_id, 1, type: :string, json_name: "repositoryId"
end

defmodule InternalApi.Repository.RegenerateWebhookSecretResponse do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.0", syntax: :proto3

  field :secret, 1, type: :string
end

defmodule InternalApi.Repository.RepositoryService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Repository.RepositoryService",
    protoc_gen_elixir_version: "0.14.0"

  rpc :Describe, InternalApi.Repository.DescribeRequest, InternalApi.Repository.DescribeResponse

  rpc :DescribeMany,
      InternalApi.Repository.DescribeManyRequest,
      InternalApi.Repository.DescribeManyResponse

  rpc :List, InternalApi.Repository.ListRequest, InternalApi.Repository.ListResponse

  rpc :Create, InternalApi.Repository.CreateRequest, InternalApi.Repository.CreateResponse

  rpc :Update, InternalApi.Repository.UpdateRequest, InternalApi.Repository.UpdateResponse

  rpc :Delete, InternalApi.Repository.DeleteRequest, InternalApi.Repository.DeleteResponse

  rpc :GetFile, InternalApi.Repository.GetFileRequest, InternalApi.Repository.GetFileResponse

  rpc :GetFiles, InternalApi.Repository.GetFilesRequest, InternalApi.Repository.GetFilesResponse

  rpc :GetChangedFilePaths,
      InternalApi.Repository.GetChangedFilePathsRequest,
      InternalApi.Repository.GetChangedFilePathsResponse

  rpc :Commit, InternalApi.Repository.CommitRequest, InternalApi.Repository.CommitResponse

  rpc :GetSshKey,
      InternalApi.Repository.GetSshKeyRequest,
      InternalApi.Repository.GetSshKeyResponse

  rpc :ListAccessibleRepositories,
      InternalApi.Repository.ListAccessibleRepositoriesRequest,
      InternalApi.Repository.ListAccessibleRepositoriesResponse

  rpc :ListCollaborators,
      InternalApi.Repository.ListCollaboratorsRequest,
      InternalApi.Repository.ListCollaboratorsResponse

  rpc :CreateBuildStatus,
      InternalApi.Repository.CreateBuildStatusRequest,
      InternalApi.Repository.CreateBuildStatusResponse

  rpc :CheckDeployKey,
      InternalApi.Repository.CheckDeployKeyRequest,
      InternalApi.Repository.CheckDeployKeyResponse

  rpc :RegenerateDeployKey,
      InternalApi.Repository.RegenerateDeployKeyRequest,
      InternalApi.Repository.RegenerateDeployKeyResponse

  rpc :CheckWebhook,
      InternalApi.Repository.CheckWebhookRequest,
      InternalApi.Repository.CheckWebhookResponse

  rpc :RegenerateWebhook,
      InternalApi.Repository.RegenerateWebhookRequest,
      InternalApi.Repository.RegenerateWebhookResponse

  rpc :Fork, InternalApi.Repository.ForkRequest, InternalApi.Repository.ForkResponse

  rpc :DescribeRemoteRepository,
      InternalApi.Repository.DescribeRemoteRepositoryRequest,
      InternalApi.Repository.DescribeRemoteRepositoryResponse

  rpc :DescribeRevision,
      InternalApi.Repository.DescribeRevisionRequest,
      InternalApi.Repository.DescribeRevisionResponse

  rpc :VerifyWebhookSignature,
      InternalApi.Repository.VerifyWebhookSignatureRequest,
      InternalApi.Repository.VerifyWebhookSignatureResponse

  rpc :ClearExternalData,
      InternalApi.Repository.ClearExternalDataRequest,
      InternalApi.Repository.ClearExternalDataResponse

  rpc :RegenerateWebhookSecret,
      InternalApi.Repository.RegenerateWebhookSecretRequest,
      InternalApi.Repository.RegenerateWebhookSecretResponse
end

defmodule InternalApi.Repository.RepositoryService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Repository.RepositoryService.Service
end
