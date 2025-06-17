defmodule InternalApi.Projecthub.ResponseMeta.Code do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:OK, 0)
  field(:NOT_FOUND, 2)
  field(:FAILED_PRECONDITION, 3)
end

defmodule InternalApi.Projecthub.Project.Spec.Visibility do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:PRIVATE, 0)
  field(:PUBLIC, 1)
end

defmodule InternalApi.Projecthub.Project.Spec.PermissionType do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:EMPTY, 0)
  field(:DEFAULT_BRANCH, 1)
  field(:NON_DEFAULT_BRANCH, 2)
  field(:PULL_REQUEST, 3)
  field(:FORKED_PULL_REQUEST, 4)
  field(:TAG, 5)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.RunType do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:BRANCHES, 0)
  field(:TAGS, 1)
  field(:PULL_REQUESTS, 2)
  field(:FORKED_PULL_REQUESTS, 3)
  field(:DRAFT_PULL_REQUESTS, 4)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:BLOCK, 0)
  field(:PIPELINE, 1)
end

defmodule InternalApi.Projecthub.Project.Spec.Scheduler.Status do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:STATUS_UNSPECIFIED, 0)
  field(:STATUS_INACTIVE, 1)
  field(:STATUS_ACTIVE, 2)
end

defmodule InternalApi.Projecthub.Project.Spec.Task.Status do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:STATUS_UNSPECIFIED, 0)
  field(:STATUS_INACTIVE, 1)
  field(:STATUS_ACTIVE, 2)
end

defmodule InternalApi.Projecthub.Project.Status.State do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:INITIALIZING, 0)
  field(:READY, 1)
  field(:ERROR, 2)
  field(:ONBOARDING, 3)
end

defmodule InternalApi.Projecthub.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Projecthub.RequestMeta do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:api_version, 1, type: :string, json_name: "apiVersion")
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string, json_name: "reqId")
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:user_id, 5, type: :string, json_name: "userId")
end

defmodule InternalApi.Projecthub.ResponseMeta.Status do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:code, 1, type: InternalApi.Projecthub.ResponseMeta.Code, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Projecthub.ResponseMeta do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:api_version, 1, type: :string, json_name: "apiVersion")
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string, json_name: "reqId")
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:user_id, 5, type: :string, json_name: "userId")
  field(:status, 6, type: InternalApi.Projecthub.ResponseMeta.Status)
end

defmodule InternalApi.Projecthub.PaginationRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
end

defmodule InternalApi.Projecthub.PaginationResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:page_number, 1, type: :int32, json_name: "pageNumber")
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:total_entries, 3, type: :int32, json_name: "totalEntries")
  field(:total_pages, 4, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.Projecthub.Project.Metadata do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:owner_id, 3, type: :string, json_name: "ownerId")
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:description, 5, type: :string)
  field(:created_at, 6, type: Google.Protobuf.Timestamp, json_name: "createdAt")
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:allowed_secrets, 1, repeated: true, type: :string, json_name: "allowedSecrets")
  field(:allowed_contributors, 2, repeated: true, type: :string, json_name: "allowedContributors")
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:path, 1, type: :string)

  field(:level, 2,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level,
    enum: true
  )
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:pipeline_files, 1,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile,
    json_name: "pipelineFiles"
  )
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Whitelist do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:branches, 1, repeated: true, type: :string)
  field(:tags, 2, repeated: true, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  oneof(:run_present, 0)

  field(:url, 1, type: :string)
  field(:name, 2, type: :string)
  field(:owner, 3, type: :string)

  field(:run_on, 4,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.Repository.RunType,
    json_name: "runOn",
    enum: true
  )

  field(:forked_pull_requests, 5,
    type: InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests,
    json_name: "forkedPullRequests"
  )

  field(:run, 6, type: :bool, oneof: 0)
  field(:pipeline_file, 7, type: :string, json_name: "pipelineFile")
  field(:status, 8, type: InternalApi.Projecthub.Project.Spec.Repository.Status)
  field(:whitelist, 9, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist)
  field(:public, 10, type: :bool)

  field(:integration_type, 11,
    type: InternalApi.RepositoryIntegrator.IntegrationType,
    json_name: "integrationType",
    enum: true
  )

  field(:connected, 12, type: :bool)
  field(:id, 13, type: :string)
  field(:default_branch, 14, type: :string, json_name: "defaultBranch")
end

defmodule InternalApi.Projecthub.Project.Spec.Scheduler do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:at, 4, type: :string)
  field(:pipeline_file, 5, type: :string, json_name: "pipelineFile")
  field(:status, 6, type: InternalApi.Projecthub.Project.Spec.Scheduler.Status, enum: true)
end

defmodule InternalApi.Projecthub.Project.Spec.Task.Parameter do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:name, 1, type: :string)
  field(:required, 2, type: :bool)
  field(:description, 3, type: :string)
  field(:default_value, 4, type: :string, json_name: "defaultValue")
  field(:options, 5, repeated: true, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Task do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:at, 4, type: :string)
  field(:pipeline_file, 5, type: :string, json_name: "pipelineFile")
  field(:status, 6, type: InternalApi.Projecthub.Project.Spec.Task.Status, enum: true)
  field(:recurring, 7, type: :bool)
  field(:parameters, 8, repeated: true, type: InternalApi.Projecthub.Project.Spec.Task.Parameter)
  field(:description, 9, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:repository, 1, type: InternalApi.Projecthub.Project.Spec.Repository)
  field(:schedulers, 2, repeated: true, type: InternalApi.Projecthub.Project.Spec.Scheduler)
  field(:private, 3, type: :bool)
  field(:public, 4, type: :bool)
  field(:visibility, 5, type: InternalApi.Projecthub.Project.Spec.Visibility, enum: true)

  field(:debug_permissions, 6,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.PermissionType,
    json_name: "debugPermissions",
    enum: true
  )

  field(:attach_permissions, 7,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.PermissionType,
    json_name: "attachPermissions",
    enum: true
  )

  field(:custom_permissions, 8, type: :bool, json_name: "customPermissions")
  field(:artifact_store_id, 9, type: :string, json_name: "artifactStoreId")
  field(:cache_id, 10, type: :string, json_name: "cacheId")
  field(:docker_registry_id, 11, type: :string, json_name: "dockerRegistryId")
  field(:tasks, 12, repeated: true, type: InternalApi.Projecthub.Project.Spec.Task)
end

defmodule InternalApi.Projecthub.Project.Status.Cache do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.ArtifactStore do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Repository do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Analysis do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Permissions do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
  field(:state_reason, 2, type: :string, json_name: "stateReason")
  field(:cache, 3, type: InternalApi.Projecthub.Project.Status.Cache)

  field(:artifact_store, 4,
    type: InternalApi.Projecthub.Project.Status.ArtifactStore,
    json_name: "artifactStore"
  )

  field(:repository, 5, type: InternalApi.Projecthub.Project.Status.Repository)
  field(:analysis, 6, type: InternalApi.Projecthub.Project.Status.Analysis)
  field(:permissions, 7, type: InternalApi.Projecthub.Project.Status.Permissions)
end

defmodule InternalApi.Projecthub.Project do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.Project.Metadata)
  field(:spec, 2, type: InternalApi.Projecthub.Project.Spec)
  field(:status, 3, type: InternalApi.Projecthub.Project.Status)
end

defmodule InternalApi.Projecthub.ListRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:pagination, 2, type: InternalApi.Projecthub.PaginationRequest)
  field(:owner_id, 3, type: :string, json_name: "ownerId")
  field(:repo_url, 4, type: :string, json_name: "repoUrl")
  field(:soft_deleted, 5, type: :bool, json_name: "softDeleted")
end

defmodule InternalApi.Projecthub.ListResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:pagination, 2, type: InternalApi.Projecthub.PaginationResponse)
  field(:projects, 3, repeated: true, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.ListKeysetRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:direction, 4, type: InternalApi.Projecthub.ListKeysetRequest.Direction, enum: true)
  field(:owner_id, 5, type: :string, json_name: "ownerId")
  field(:repo_url, 6, type: :string, json_name: "repoUrl")
  field(:created_after, 7, type: Google.Protobuf.Timestamp, json_name: "createdAfter")
end

defmodule InternalApi.Projecthub.ListKeysetResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:projects, 2, repeated: true, type: InternalApi.Projecthub.Project)
  field(:next_page_token, 3, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 4, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.Projecthub.DescribeRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:detailed, 4, type: :bool)
  field(:soft_deleted, 5, type: :bool, json_name: "softDeleted")
end

defmodule InternalApi.Projecthub.DescribeResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.DescribeManyRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:ids, 2, repeated: true, type: :string)
  field(:soft_deleted, 3, type: :bool, json_name: "softDeleted")
end

defmodule InternalApi.Projecthub.DescribeManyResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:projects, 2, repeated: true, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.CreateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
  field(:skip_onboarding, 3, type: :bool, json_name: "skipOnboarding")
end

defmodule InternalApi.Projecthub.CreateResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.UpdateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
  field(:omit_schedulers_and_tasks, 3, type: :bool, json_name: "omitSchedulersAndTasks")
end

defmodule InternalApi.Projecthub.UpdateResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.DestroyRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Projecthub.DestroyResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.RestoreRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RestoreResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.UsersRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.UsersResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:users, 2, repeated: true, type: InternalApi.User.User)
end

defmodule InternalApi.Projecthub.CheckDeployKeyRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:title, 1, type: :string)
  field(:fingerprint, 2, type: :string)
  field(:created_at, 3, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:public_key, 4, type: :string, json_name: "publicKey")
end

defmodule InternalApi.Projecthub.CheckDeployKeyResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)

  field(:deploy_key, 2,
    type: InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey,
    json_name: "deployKey"
  )
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:title, 1, type: :string)
  field(:fingerprint, 2, type: :string)
  field(:created_at, 3, type: Google.Protobuf.Timestamp, json_name: "createdAt")
  field(:public_key, 4, type: :string, json_name: "publicKey")
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)

  field(:deploy_key, 2,
    type: InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey,
    json_name: "deployKey"
  )
end

defmodule InternalApi.Projecthub.CheckWebhookRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.CheckWebhookResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:webhook, 2, type: InternalApi.Projecthub.Webhook)
end

defmodule InternalApi.Projecthub.RegenerateWebhookRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateWebhookResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:webhook, 2, type: InternalApi.Projecthub.Webhook)
end

defmodule InternalApi.Projecthub.Webhook do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:url, 1, type: :string)
end

defmodule InternalApi.Projecthub.ChangeProjectOwnerRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:user_id, 3, type: :string, json_name: "userId")
end

defmodule InternalApi.Projecthub.ChangeProjectOwnerResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.ForkAndCreateRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.ForkAndCreateResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.GithubAppSwitchRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.GithubAppSwitchResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.FinishOnboardingRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.FinishOnboardingResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.RegenerateWebhookSecretRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateWebhookSecretResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:secret, 2, type: :string)
end

defmodule InternalApi.Projecthub.ProjectCreated do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string, json_name: "orgId")
end

defmodule InternalApi.Projecthub.ProjectDeleted do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string, json_name: "orgId")
end

defmodule InternalApi.Projecthub.ProjectRestored do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string, json_name: "orgId")
end

defmodule InternalApi.Projecthub.ProjectUpdated do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.CollaboratorsChanged do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.ProjectService.Service do
  @moduledoc false
  use GRPC.Service,
    name: "InternalApi.Projecthub.ProjectService",
    protoc_gen_elixir_version: "0.11.0"

  rpc(:List, InternalApi.Projecthub.ListRequest, InternalApi.Projecthub.ListResponse)

  rpc(
    :ListKeyset,
    InternalApi.Projecthub.ListKeysetRequest,
    InternalApi.Projecthub.ListKeysetResponse
  )

  rpc(:Describe, InternalApi.Projecthub.DescribeRequest, InternalApi.Projecthub.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.Projecthub.DescribeManyRequest,
    InternalApi.Projecthub.DescribeManyResponse
  )

  rpc(:Create, InternalApi.Projecthub.CreateRequest, InternalApi.Projecthub.CreateResponse)

  rpc(:Update, InternalApi.Projecthub.UpdateRequest, InternalApi.Projecthub.UpdateResponse)

  rpc(:Destroy, InternalApi.Projecthub.DestroyRequest, InternalApi.Projecthub.DestroyResponse)

  rpc(:Restore, InternalApi.Projecthub.RestoreRequest, InternalApi.Projecthub.RestoreResponse)

  rpc(:Users, InternalApi.Projecthub.UsersRequest, InternalApi.Projecthub.UsersResponse)

  rpc(
    :CheckDeployKey,
    InternalApi.Projecthub.CheckDeployKeyRequest,
    InternalApi.Projecthub.CheckDeployKeyResponse
  )

  rpc(
    :RegenerateDeployKey,
    InternalApi.Projecthub.RegenerateDeployKeyRequest,
    InternalApi.Projecthub.RegenerateDeployKeyResponse
  )

  rpc(
    :CheckWebhook,
    InternalApi.Projecthub.CheckWebhookRequest,
    InternalApi.Projecthub.CheckWebhookResponse
  )

  rpc(
    :RegenerateWebhook,
    InternalApi.Projecthub.RegenerateWebhookRequest,
    InternalApi.Projecthub.RegenerateWebhookResponse
  )

  rpc(
    :RegenerateWebhookSecret,
    InternalApi.Projecthub.RegenerateWebhookSecretRequest,
    InternalApi.Projecthub.RegenerateWebhookSecretResponse
  )

  rpc(
    :ChangeProjectOwner,
    InternalApi.Projecthub.ChangeProjectOwnerRequest,
    InternalApi.Projecthub.ChangeProjectOwnerResponse
  )

  rpc(
    :ForkAndCreate,
    InternalApi.Projecthub.ForkAndCreateRequest,
    InternalApi.Projecthub.ForkAndCreateResponse
  )

  rpc(
    :GithubAppSwitch,
    InternalApi.Projecthub.GithubAppSwitchRequest,
    InternalApi.Projecthub.GithubAppSwitchResponse
  )

  rpc(
    :FinishOnboarding,
    InternalApi.Projecthub.FinishOnboardingRequest,
    InternalApi.Projecthub.FinishOnboardingResponse
  )
end

defmodule InternalApi.Projecthub.ProjectService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Projecthub.ProjectService.Service
end
