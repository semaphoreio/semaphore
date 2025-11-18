defmodule InternalApi.Projecthub.RequestMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_version: String.t(),
          kind: String.t(),
          req_id: String.t(),
          org_id: String.t(),
          user_id: String.t()
        }
  defstruct [:api_version, :kind, :req_id, :org_id, :user_id]

  field(:api_version, 1, type: :string)
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:user_id, 5, type: :string)
end

defmodule InternalApi.Projecthub.ResponseMeta do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          api_version: String.t(),
          kind: String.t(),
          req_id: String.t(),
          org_id: String.t(),
          user_id: String.t(),
          status: InternalApi.Projecthub.ResponseMeta.Status.t()
        }
  defstruct [:api_version, :kind, :req_id, :org_id, :user_id, :status]

  field(:api_version, 1, type: :string)
  field(:kind, 2, type: :string)
  field(:req_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:user_id, 5, type: :string)
  field(:status, 6, type: InternalApi.Projecthub.ResponseMeta.Status)
end

defmodule InternalApi.Projecthub.ResponseMeta.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field(:code, 1, type: InternalApi.Projecthub.ResponseMeta.Code, enum: true)
  field(:message, 2, type: :string)
end

defmodule InternalApi.Projecthub.ResponseMeta.Code do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:OK, 0)
  field(:NOT_FOUND, 2)
  field(:FAILED_PRECONDITION, 3)
end

defmodule InternalApi.Projecthub.PaginationRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer
        }
  defstruct [:page, :page_size]

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32)
end

defmodule InternalApi.Projecthub.PaginationResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:page_number, :page_size, :total_entries, :total_pages]

  field(:page_number, 1, type: :int32)
  field(:page_size, 2, type: :int32)
  field(:total_entries, 3, type: :int32)
  field(:total_pages, 4, type: :int32)
end

defmodule InternalApi.Projecthub.Project do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.Project.Metadata.t(),
          spec: InternalApi.Projecthub.Project.Spec.t(),
          status: InternalApi.Projecthub.Project.Status.t()
        }
  defstruct [:metadata, :spec, :status]

  field(:metadata, 1, type: InternalApi.Projecthub.Project.Metadata)
  field(:spec, 2, type: InternalApi.Projecthub.Project.Spec)
  field(:status, 3, type: InternalApi.Projecthub.Project.Status)
end

defmodule InternalApi.Projecthub.Project.Metadata do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          id: String.t(),
          owner_id: String.t(),
          org_id: String.t(),
          description: String.t(),
          created_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:name, :id, :owner_id, :org_id, :description, :created_at]

  field(:name, 1, type: :string)
  field(:id, 2, type: :string)
  field(:owner_id, 3, type: :string)
  field(:org_id, 4, type: :string)
  field(:description, 5, type: :string)
  field(:created_at, 6, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.Project.Spec do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          repository: InternalApi.Projecthub.Project.Spec.Repository.t(),
          schedulers: [InternalApi.Projecthub.Project.Spec.Scheduler.t()],
          private: boolean,
          public: boolean,
          visibility: integer,
          debug_permissions: [integer],
          attach_permissions: [integer],
          custom_permissions: boolean,
          artifact_store_id: String.t(),
          cache_id: String.t(),
          docker_registry_id: String.t(),
          tasks: [InternalApi.Projecthub.Project.Spec.Task.t()]
        }
  defstruct [
    :repository,
    :schedulers,
    :private,
    :public,
    :visibility,
    :debug_permissions,
    :attach_permissions,
    :custom_permissions,
    :artifact_store_id,
    :cache_id,
    :docker_registry_id,
    :tasks
  ]

  field(:repository, 1, type: InternalApi.Projecthub.Project.Spec.Repository)
  field(:schedulers, 2, repeated: true, type: InternalApi.Projecthub.Project.Spec.Scheduler)
  field(:private, 3, type: :bool)
  field(:public, 4, type: :bool)
  field(:visibility, 5, type: InternalApi.Projecthub.Project.Spec.Visibility, enum: true)

  field(
    :debug_permissions,
    6,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.PermissionType,
    enum: true
  )

  field(
    :attach_permissions,
    7,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.PermissionType,
    enum: true
  )

  field(:custom_permissions, 8, type: :bool)
  field(:artifact_store_id, 9, type: :string)
  field(:cache_id, 10, type: :string)
  field(:docker_registry_id, 11, type: :string)
  field(:tasks, 12, repeated: true, type: InternalApi.Projecthub.Project.Spec.Task)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          run_present: {atom, any},
          url: String.t(),
          name: String.t(),
          owner: String.t(),
          run_on: [integer],
          forked_pull_requests:
            InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests.t(),
          pipeline_file: String.t(),
          status: InternalApi.Projecthub.Project.Spec.Repository.Status.t(),
          whitelist: InternalApi.Projecthub.Project.Spec.Repository.Whitelist.t(),
          public: boolean,
          integration_type: integer,
          connected: boolean,
          id: String.t(),
          default_branch: String.t()
        }
  defstruct [
    :run_present,
    :url,
    :name,
    :owner,
    :run_on,
    :forked_pull_requests,
    :pipeline_file,
    :status,
    :whitelist,
    :public,
    :integration_type,
    :connected,
    :id,
    :default_branch
  ]

  oneof(:run_present, 0)
  field(:url, 1, type: :string)
  field(:name, 2, type: :string)
  field(:owner, 3, type: :string)

  field(
    :run_on,
    4,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.Repository.RunType,
    enum: true
  )

  field(
    :forked_pull_requests,
    5,
    type: InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests
  )

  field(:run, 6, type: :bool, oneof: 0)
  field(:pipeline_file, 7, type: :string)
  field(:status, 8, type: InternalApi.Projecthub.Project.Spec.Repository.Status)
  field(:whitelist, 9, type: InternalApi.Projecthub.Project.Spec.Repository.Whitelist)
  field(:public, 10, type: :bool)
  field(:integration_type, 11, type: InternalApi.RepositoryIntegrator.IntegrationType, enum: true)
  field(:connected, 12, type: :bool)
  field(:id, 13, type: :string)
  field(:default_branch, 14, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.ForkedPullRequests do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          allowed_secrets: [String.t()],
          allowed_contributors: [String.t()]
        }
  defstruct [:allowed_secrets, :allowed_contributors]

  field(:allowed_secrets, 1, repeated: true, type: :string)
  field(:allowed_contributors, 2, repeated: true, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_files: [InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.t()]
        }
  defstruct [:pipeline_files]

  field(
    :pipeline_files,
    1,
    repeated: true,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile
  )
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          path: String.t(),
          level: integer
        }
  defstruct [:path, :level]

  field(:path, 1, type: :string)

  field(
    :level,
    2,
    type: InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level,
    enum: true
  )
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Status.PipelineFile.Level do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BLOCK, 0)
  field(:PIPELINE, 1)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.Whitelist do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          branches: [String.t()],
          tags: [String.t()]
        }
  defstruct [:branches, :tags]

  field(:branches, 1, repeated: true, type: :string)
  field(:tags, 2, repeated: true, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Repository.RunType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCHES, 0)
  field(:TAGS, 1)
  field(:PULL_REQUESTS, 2)
  field(:FORKED_PULL_REQUESTS, 3)
  field(:DRAFT_PULL_REQUESTS, 4)
end

defmodule InternalApi.Projecthub.Project.Spec.Scheduler do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          branch: String.t(),
          at: String.t(),
          pipeline_file: String.t(),
          status: integer
        }
  defstruct [:id, :name, :branch, :at, :pipeline_file, :status]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:at, 4, type: :string)
  field(:pipeline_file, 5, type: :string)
  field(:status, 6, type: InternalApi.Projecthub.Project.Spec.Scheduler.Status, enum: true)
end

defmodule InternalApi.Projecthub.Project.Spec.Scheduler.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:STATUS_UNSPECIFIED, 0)
  field(:STATUS_INACTIVE, 1)
  field(:STATUS_ACTIVE, 2)
end

defmodule InternalApi.Projecthub.Project.Spec.Task do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          branch: String.t(),
          at: String.t(),
          pipeline_file: String.t(),
          status: integer,
          recurring: boolean,
          parameters: [InternalApi.Projecthub.Project.Spec.Task.Parameter.t()],
          description: String.t()
        }
  defstruct [
    :id,
    :name,
    :branch,
    :at,
    :pipeline_file,
    :status,
    :recurring,
    :parameters,
    :description
  ]

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:branch, 3, type: :string)
  field(:at, 4, type: :string)
  field(:pipeline_file, 5, type: :string)
  field(:status, 6, type: InternalApi.Projecthub.Project.Spec.Task.Status, enum: true)
  field(:recurring, 7, type: :bool)
  field(:parameters, 8, repeated: true, type: InternalApi.Projecthub.Project.Spec.Task.Parameter)
  field(:description, 9, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Task.Parameter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          required: boolean,
          description: String.t(),
          default_value: String.t(),
          options: [String.t()]
        }
  defstruct [:name, :required, :description, :default_value, :options]

  field(:name, 1, type: :string)
  field(:required, 2, type: :bool)
  field(:description, 3, type: :string)
  field(:default_value, 4, type: :string)
  field(:options, 5, repeated: true, type: :string)
end

defmodule InternalApi.Projecthub.Project.Spec.Task.Status do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:STATUS_UNSPECIFIED, 0)
  field(:STATUS_INACTIVE, 1)
  field(:STATUS_ACTIVE, 2)
end

defmodule InternalApi.Projecthub.Project.Spec.Visibility do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:PRIVATE, 0)
  field(:PUBLIC, 1)
end

defmodule InternalApi.Projecthub.Project.Spec.PermissionType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:EMPTY, 0)
  field(:DEFAULT_BRANCH, 1)
  field(:NON_DEFAULT_BRANCH, 2)
  field(:PULL_REQUEST, 3)
  field(:FORKED_PULL_REQUEST, 4)
  field(:TAG, 5)
end

defmodule InternalApi.Projecthub.Project.Status do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer,
          state_reason: String.t(),
          cache: InternalApi.Projecthub.Project.Status.Cache.t(),
          artifact_store: InternalApi.Projecthub.Project.Status.ArtifactStore.t(),
          repository: InternalApi.Projecthub.Project.Status.Repository.t(),
          analysis: InternalApi.Projecthub.Project.Status.Analysis.t(),
          permissions: InternalApi.Projecthub.Project.Status.Permissions.t()
        }
  defstruct [:state, :state_reason, :cache, :artifact_store, :repository, :analysis, :permissions]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
  field(:state_reason, 2, type: :string)
  field(:cache, 3, type: InternalApi.Projecthub.Project.Status.Cache)
  field(:artifact_store, 4, type: InternalApi.Projecthub.Project.Status.ArtifactStore)
  field(:repository, 5, type: InternalApi.Projecthub.Project.Status.Repository)
  field(:analysis, 6, type: InternalApi.Projecthub.Project.Status.Analysis)
  field(:permissions, 7, type: InternalApi.Projecthub.Project.Status.Permissions)
end

defmodule InternalApi.Projecthub.Project.Status.Cache do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer
        }
  defstruct [:state]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.ArtifactStore do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer
        }
  defstruct [:state]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Repository do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer
        }
  defstruct [:state]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Analysis do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer
        }
  defstruct [:state]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.Permissions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: integer
        }
  defstruct [:state]

  field(:state, 1, type: InternalApi.Projecthub.Project.Status.State, enum: true)
end

defmodule InternalApi.Projecthub.Project.Status.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:INITIALIZING, 0)
  field(:READY, 1)
  field(:ERROR, 2)
  field(:ONBOARDING, 3)
end

defmodule InternalApi.Projecthub.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          pagination: InternalApi.Projecthub.PaginationRequest.t(),
          owner_id: String.t(),
          repo_url: String.t(),
          soft_deleted: boolean
        }
  defstruct [:metadata, :pagination, :owner_id, :repo_url, :soft_deleted]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:pagination, 2, type: InternalApi.Projecthub.PaginationRequest)
  field(:owner_id, 3, type: :string)
  field(:repo_url, 4, type: :string)
  field(:soft_deleted, 5, type: :bool)
end

defmodule InternalApi.Projecthub.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          pagination: InternalApi.Projecthub.PaginationResponse.t(),
          projects: [InternalApi.Projecthub.Project.t()]
        }
  defstruct [:metadata, :pagination, :projects]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:pagination, 2, type: InternalApi.Projecthub.PaginationResponse)
  field(:projects, 3, repeated: true, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          page_size: integer,
          page_token: String.t(),
          direction: integer,
          owner_id: String.t(),
          repo_url: String.t(),
          created_after: Google.Protobuf.Timestamp.t()
        }
  defstruct [:metadata, :page_size, :page_token, :direction, :owner_id, :repo_url, :created_after]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:direction, 4, type: InternalApi.Projecthub.ListKeysetRequest.Direction, enum: true)
  field(:owner_id, 5, type: :string)
  field(:repo_url, 6, type: :string)
  field(:created_after, 7, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.Projecthub.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          projects: [InternalApi.Projecthub.Project.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:metadata, :projects, :next_page_token, :previous_page_token]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:projects, 2, repeated: true, type: InternalApi.Projecthub.Project)
  field(:next_page_token, 3, type: :string)
  field(:previous_page_token, 4, type: :string)
end

defmodule InternalApi.Projecthub.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t(),
          name: String.t(),
          detailed: boolean,
          soft_deleted: boolean
        }
  defstruct [:metadata, :id, :name, :detailed, :soft_deleted]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:detailed, 4, type: :bool)
  field(:soft_deleted, 5, type: :bool)
end

defmodule InternalApi.Projecthub.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          project: InternalApi.Projecthub.Project.t()
        }
  defstruct [:metadata, :project]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          ids: [String.t()],
          soft_deleted: boolean
        }
  defstruct [:metadata, :ids, :soft_deleted]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:ids, 2, repeated: true, type: :string)
  field(:soft_deleted, 3, type: :bool)
end

defmodule InternalApi.Projecthub.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          projects: [InternalApi.Projecthub.Project.t()]
        }
  defstruct [:metadata, :projects]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:projects, 2, repeated: true, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          project: InternalApi.Projecthub.Project.t(),
          skip_onboarding: boolean
        }
  defstruct [:metadata, :project, :skip_onboarding]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
  field(:skip_onboarding, 3, type: :bool)
end

defmodule InternalApi.Projecthub.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          project: InternalApi.Projecthub.Project.t()
        }
  defstruct [:metadata, :project]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.UpdateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          project: InternalApi.Projecthub.Project.t(),
          omit_schedulers_and_tasks: boolean
        }
  defstruct [:metadata, :project, :omit_schedulers_and_tasks]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
  field(:omit_schedulers_and_tasks, 3, type: :bool)
end

defmodule InternalApi.Projecthub.UpdateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          project: InternalApi.Projecthub.Project.t()
        }
  defstruct [:metadata, :project]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.DestroyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t(),
          name: String.t()
        }
  defstruct [:metadata, :id, :name]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
end

defmodule InternalApi.Projecthub.DestroyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t()
        }
  defstruct [:metadata]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.RestoreRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RestoreResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t()
        }
  defstruct [:metadata]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.UsersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.UsersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          users: [InternalApi.User.User.t()]
        }
  defstruct [:metadata, :users]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:users, 2, repeated: true, type: InternalApi.User.User)
end

defmodule InternalApi.Projecthub.CheckDeployKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.CheckDeployKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          deploy_key: InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey.t()
        }
  defstruct [:metadata, :deploy_key]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:deploy_key, 2, type: InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey)
end

defmodule InternalApi.Projecthub.CheckDeployKeyResponse.DeployKey do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          title: String.t(),
          fingerprint: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          public_key: String.t()
        }
  defstruct [:title, :fingerprint, :created_at, :public_key]

  field(:title, 1, type: :string)
  field(:fingerprint, 2, type: :string)
  field(:created_at, 3, type: Google.Protobuf.Timestamp)
  field(:public_key, 4, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          deploy_key: InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey.t()
        }
  defstruct [:metadata, :deploy_key]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:deploy_key, 2, type: InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey)
end

defmodule InternalApi.Projecthub.RegenerateDeployKeyResponse.DeployKey do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          title: String.t(),
          fingerprint: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          public_key: String.t()
        }
  defstruct [:title, :fingerprint, :created_at, :public_key]

  field(:title, 1, type: :string)
  field(:fingerprint, 2, type: :string)
  field(:created_at, 3, type: Google.Protobuf.Timestamp)
  field(:public_key, 4, type: :string)
end

defmodule InternalApi.Projecthub.CheckWebhookRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.CheckWebhookResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          webhook: InternalApi.Projecthub.Webhook.t()
        }
  defstruct [:metadata, :webhook]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:webhook, 2, type: InternalApi.Projecthub.Webhook)
end

defmodule InternalApi.Projecthub.RegenerateWebhookRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateWebhookResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          webhook: InternalApi.Projecthub.Webhook.t()
        }
  defstruct [:metadata, :webhook]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:webhook, 2, type: InternalApi.Projecthub.Webhook)
end

defmodule InternalApi.Projecthub.Webhook do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          url: String.t()
        }
  defstruct [:url]

  field(:url, 1, type: :string)
end

defmodule InternalApi.Projecthub.ChangeProjectOwnerRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t(),
          user_id: String.t()
        }
  defstruct [:metadata, :id, :user_id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
  field(:user_id, 3, type: :string)
end

defmodule InternalApi.Projecthub.ChangeProjectOwnerResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t()
        }
  defstruct [:metadata]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.ForkAndCreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          project: InternalApi.Projecthub.Project.t()
        }
  defstruct [:metadata, :project]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.ForkAndCreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          project: InternalApi.Projecthub.Project.t()
        }
  defstruct [:metadata, :project]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:project, 2, type: InternalApi.Projecthub.Project)
end

defmodule InternalApi.Projecthub.GithubAppSwitchRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.GithubAppSwitchResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t()
        }
  defstruct [:metadata]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.FinishOnboardingRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.FinishOnboardingResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t()
        }
  defstruct [:metadata]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
end

defmodule InternalApi.Projecthub.RegenerateWebhookSecretRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.RequestMeta.t(),
          id: String.t()
        }
  defstruct [:metadata, :id]

  field(:metadata, 1, type: InternalApi.Projecthub.RequestMeta)
  field(:id, 2, type: :string)
end

defmodule InternalApi.Projecthub.RegenerateWebhookSecretResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metadata: InternalApi.Projecthub.ResponseMeta.t(),
          secret: String.t()
        }
  defstruct [:metadata, :secret]

  field(:metadata, 1, type: InternalApi.Projecthub.ResponseMeta)
  field(:secret, 2, type: :string)
end

defmodule InternalApi.Projecthub.ProjectCreated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          org_id: String.t()
        }
  defstruct [:project_id, :timestamp, :org_id]

  field(:project_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string)
end

defmodule InternalApi.Projecthub.ProjectDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          org_id: String.t()
        }
  defstruct [:project_id, :timestamp, :org_id]

  field(:project_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string)
end

defmodule InternalApi.Projecthub.ProjectRestored do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          org_id: String.t()
        }
  defstruct [:project_id, :timestamp, :org_id]

  field(:project_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
  field(:org_id, 3, type: :string)
end

defmodule InternalApi.Projecthub.ProjectUpdated do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          org_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:project_id, :org_id, :timestamp]

  field(:project_id, 1, type: :string)
  field(:org_id, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.CollaboratorsChanged do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:project_id, :timestamp]

  field(:project_id, 1, type: :string)
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Projecthub.ProjectService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Projecthub.ProjectService"

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
