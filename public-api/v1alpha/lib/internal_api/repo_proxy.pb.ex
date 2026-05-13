defmodule InternalApi.RepoProxy.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_id: String.t()
        }
  defstruct [:hook_id]

  field :hook_id, 1, type: :string
end

defmodule InternalApi.RepoProxy.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          hook: InternalApi.RepoProxy.Hook.t()
        }
  defstruct [:status, :hook]

  field :status, 1, type: InternalApi.ResponseStatus
  field :hook, 2, type: InternalApi.RepoProxy.Hook
end

defmodule InternalApi.RepoProxy.Hook do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_id: String.t(),
          head_commit_sha: String.t(),
          commit_message: String.t(),
          commit_range: String.t(),
          commit_author: String.t(),
          repo_host_url: String.t(),
          repo_host_username: String.t(),
          repo_host_email: String.t(),
          repo_host_avatar_url: String.t(),
          repo_host_uid: String.t(),
          user_id: String.t(),
          semaphore_email: String.t(),
          repo_slug: String.t(),
          git_ref: String.t(),
          git_ref_type: integer,
          pr_slug: String.t(),
          pr_name: String.t(),
          pr_number: String.t(),
          pr_sha: String.t(),
          pr_mergeable: boolean,
          pr_branch_name: String.t(),
          tag_name: String.t(),
          branch_name: String.t()
        }
  defstruct [
    :hook_id,
    :head_commit_sha,
    :commit_message,
    :commit_range,
    :commit_author,
    :repo_host_url,
    :repo_host_username,
    :repo_host_email,
    :repo_host_avatar_url,
    :repo_host_uid,
    :user_id,
    :semaphore_email,
    :repo_slug,
    :git_ref,
    :git_ref_type,
    :pr_slug,
    :pr_name,
    :pr_number,
    :pr_sha,
    :pr_mergeable,
    :pr_branch_name,
    :tag_name,
    :branch_name
  ]

  field :hook_id, 1, type: :string
  field :head_commit_sha, 2, type: :string
  field :commit_message, 3, type: :string
  field :commit_range, 21, type: :string
  field :commit_author, 24, type: :string
  field :repo_host_url, 4, type: :string
  field :repo_host_username, 7, type: :string
  field :repo_host_email, 8, type: :string
  field :repo_host_avatar_url, 10, type: :string
  field :repo_host_uid, 25, type: :string
  field :user_id, 9, type: :string
  field :semaphore_email, 6, type: :string
  field :repo_slug, 17, type: :string
  field :git_ref, 20, type: :string
  field :git_ref_type, 15, type: InternalApi.RepoProxy.Hook.Type, enum: true
  field :pr_slug, 18, type: :string
  field :pr_name, 12, type: :string
  field :pr_number, 13, type: :string
  field :pr_sha, 19, type: :string
  field :pr_mergeable, 22, type: :bool
  field :pr_branch_name, 23, type: :string
  field :tag_name, 14, type: :string
  field :branch_name, 16, type: :string
end

defmodule InternalApi.RepoProxy.Hook.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.RepoProxy.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_ids: [String.t()]
        }
  defstruct [:hook_ids]

  field :hook_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.RepoProxy.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          hooks: [InternalApi.RepoProxy.Hook.t()]
        }
  defstruct [:status, :hooks]

  field :status, 1, type: InternalApi.ResponseStatus
  field :hooks, 2, repeated: true, type: InternalApi.RepoProxy.Hook
end

defmodule InternalApi.RepoProxy.ListBlockedHooksRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          git_ref: String.t()
        }
  defstruct [:project_id, :git_ref]

  field :project_id, 1, type: :string
  field :git_ref, 2, type: :string
end

defmodule InternalApi.RepoProxy.ListBlockedHooksResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          hooks: [InternalApi.RepoProxy.Hook.t()]
        }
  defstruct [:status, :hooks]

  field :status, 1, type: InternalApi.ResponseStatus
  field :hooks, 2, repeated: true, type: InternalApi.RepoProxy.Hook
end

defmodule InternalApi.RepoProxy.ScheduleBlockedHookRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_id: String.t(),
          project_id: String.t()
        }
  defstruct [:hook_id, :project_id]

  field :hook_id, 1, type: :string
  field :project_id, 2, type: :string
end

defmodule InternalApi.RepoProxy.ScheduleBlockedHookResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.ResponseStatus.t(),
          wf_id: String.t(),
          ppl_id: String.t()
        }
  defstruct [:status, :wf_id, :ppl_id]

  field :status, 1, type: InternalApi.ResponseStatus
  field :wf_id, 2, type: :string
  field :ppl_id, 3, type: :string
end

defmodule InternalApi.RepoProxy.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          request_token: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          definition_file: String.t(),
          triggered_by: integer,
          git: InternalApi.RepoProxy.CreateRequest.Git.t()
        }
  defstruct [:request_token, :project_id, :requester_id, :definition_file, :triggered_by, :git]

  field :request_token, 1, type: :string
  field :project_id, 2, type: :string
  field :requester_id, 3, type: :string
  field :definition_file, 4, type: :string
  field :triggered_by, 5, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :git, 6, type: InternalApi.RepoProxy.CreateRequest.Git
end

defmodule InternalApi.RepoProxy.CreateRequest.Git do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          reference: String.t(),
          commit_sha: String.t()
        }
  defstruct [:reference, :commit_sha]

  field :reference, 1, type: :string
  field :commit_sha, 2, type: :string
end

defmodule InternalApi.RepoProxy.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_id: String.t(),
          workflow_id: String.t(),
          pipeline_id: String.t()
        }
  defstruct [:hook_id, :workflow_id, :pipeline_id]

  field :hook_id, 1, type: :string
  field :workflow_id, 2, type: :string
  field :pipeline_id, 3, type: :string
end

defmodule InternalApi.RepoProxy.CreateBlankRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          request_token: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          definition_file: String.t(),
          pipeline_id: String.t(),
          wf_id: String.t(),
          triggered_by: integer,
          git: InternalApi.RepoProxy.CreateBlankRequest.Git.t()
        }
  defstruct [
    :request_token,
    :project_id,
    :requester_id,
    :definition_file,
    :pipeline_id,
    :wf_id,
    :triggered_by,
    :git
  ]

  field :request_token, 1, type: :string
  field :project_id, 2, type: :string
  field :requester_id, 3, type: :string
  field :definition_file, 4, type: :string
  field :pipeline_id, 5, type: :string
  field :wf_id, 6, type: :string
  field :triggered_by, 7, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :git, 8, type: InternalApi.RepoProxy.CreateBlankRequest.Git
end

defmodule InternalApi.RepoProxy.CreateBlankRequest.Git do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          reference: String.t(),
          commit_sha: String.t()
        }
  defstruct [:reference, :commit_sha]

  field :reference, 1, type: :string
  field :commit_sha, 2, type: :string
end

defmodule InternalApi.RepoProxy.CreateBlankResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          hook_id: String.t(),
          wf_id: String.t(),
          pipeline_id: String.t(),
          branch_id: String.t(),
          repo: InternalApi.RepoProxy.CreateBlankResponse.Repo.t()
        }
  defstruct [:hook_id, :wf_id, :pipeline_id, :branch_id, :repo]

  field :hook_id, 1, type: :string
  field :wf_id, 2, type: :string
  field :pipeline_id, 3, type: :string
  field :branch_id, 4, type: :string
  field :repo, 5, type: InternalApi.RepoProxy.CreateBlankResponse.Repo
end

defmodule InternalApi.RepoProxy.CreateBlankResponse.Repo do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          owner: String.t(),
          repo_name: String.t(),
          branch_name: String.t(),
          commit_sha: String.t(),
          repository_id: String.t()
        }
  defstruct [:owner, :repo_name, :branch_name, :commit_sha, :repository_id]

  field :owner, 1, type: :string
  field :repo_name, 2, type: :string
  field :branch_name, 3, type: :string
  field :commit_sha, 4, type: :string
  field :repository_id, 5, type: :string
end

defmodule InternalApi.RepoProxy.PullRequestUnmergeable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          branch_name: String.t(),
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:project_id, :branch_name, :timestamp]

  field :project_id, 1, type: :string
  field :branch_name, 2, type: :string
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.RepoProxy.RepoProxyService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.RepoProxy.RepoProxyService"

  rpc :Describe, InternalApi.RepoProxy.DescribeRequest, InternalApi.RepoProxy.DescribeResponse

  rpc :DescribeMany,
      InternalApi.RepoProxy.DescribeManyRequest,
      InternalApi.RepoProxy.DescribeManyResponse

  rpc :ListBlockedHooks,
      InternalApi.RepoProxy.ListBlockedHooksRequest,
      InternalApi.RepoProxy.ListBlockedHooksResponse

  rpc :ScheduleBlockedHook,
      InternalApi.RepoProxy.ScheduleBlockedHookRequest,
      InternalApi.RepoProxy.ScheduleBlockedHookResponse

  rpc :Create, InternalApi.RepoProxy.CreateRequest, InternalApi.RepoProxy.CreateResponse

  rpc :CreateBlank,
      InternalApi.RepoProxy.CreateBlankRequest,
      InternalApi.RepoProxy.CreateBlankResponse
end

defmodule InternalApi.RepoProxy.RepoProxyService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.RepoProxy.RepoProxyService.Service
end
