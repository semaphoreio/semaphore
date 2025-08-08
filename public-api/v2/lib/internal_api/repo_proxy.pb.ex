defmodule InternalApi.RepoProxy.Hook.Type do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.RepoProxy.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_id, 1, type: :string, json_name: "hookId")
end

defmodule InternalApi.RepoProxy.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:hook, 2, type: InternalApi.RepoProxy.Hook)
end

defmodule InternalApi.RepoProxy.Hook do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_id, 1, type: :string, json_name: "hookId")
  field(:head_commit_sha, 2, type: :string, json_name: "headCommitSha")
  field(:commit_message, 3, type: :string, json_name: "commitMessage")
  field(:commit_range, 21, type: :string, json_name: "commitRange")
  field(:commit_author, 24, type: :string, json_name: "commitAuthor")
  field(:repo_host_url, 4, type: :string, json_name: "repoHostUrl")
  field(:repo_host_username, 7, type: :string, json_name: "repoHostUsername")
  field(:repo_host_email, 8, type: :string, json_name: "repoHostEmail")
  field(:repo_host_avatar_url, 10, type: :string, json_name: "repoHostAvatarUrl")
  field(:repo_host_uid, 25, type: :string, json_name: "repoHostUid")
  field(:user_id, 9, type: :string, json_name: "userId")
  field(:semaphore_email, 6, type: :string, json_name: "semaphoreEmail")
  field(:repo_slug, 17, type: :string, json_name: "repoSlug")
  field(:git_ref, 20, type: :string, json_name: "gitRef")

  field(:git_ref_type, 15,
    type: InternalApi.RepoProxy.Hook.Type,
    json_name: "gitRefType",
    enum: true
  )

  field(:pr_slug, 18, type: :string, json_name: "prSlug")
  field(:pr_name, 12, type: :string, json_name: "prName")
  field(:pr_number, 13, type: :string, json_name: "prNumber")
  field(:pr_sha, 19, type: :string, json_name: "prSha")
  field(:pr_mergeable, 22, type: :bool, json_name: "prMergeable")
  field(:pr_branch_name, 23, type: :string, json_name: "prBranchName")
  field(:tag_name, 14, type: :string, json_name: "tagName")
  field(:branch_name, 16, type: :string, json_name: "branchName")
end

defmodule InternalApi.RepoProxy.DescribeManyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_ids, 1, repeated: true, type: :string, json_name: "hookIds")
end

defmodule InternalApi.RepoProxy.DescribeManyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:hooks, 2, repeated: true, type: InternalApi.RepoProxy.Hook)
end

defmodule InternalApi.RepoProxy.ListBlockedHooksRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:git_ref, 2, type: :string, json_name: "gitRef")
end

defmodule InternalApi.RepoProxy.ListBlockedHooksResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:hooks, 2, repeated: true, type: InternalApi.RepoProxy.Hook)
end

defmodule InternalApi.RepoProxy.ScheduleBlockedHookRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_id, 1, type: :string, json_name: "hookId")
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.RepoProxy.ScheduleBlockedHookResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.ResponseStatus)
  field(:wf_id, 2, type: :string, json_name: "wfId")
  field(:ppl_id, 3, type: :string, json_name: "pplId")
end

defmodule InternalApi.RepoProxy.CreateRequest.Git do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:reference, 1, type: :string)
  field(:commit_sha, 2, type: :string, json_name: "commitSha")
end

defmodule InternalApi.RepoProxy.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:request_token, 1, type: :string, json_name: "requestToken")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
  field(:definition_file, 4, type: :string, json_name: "definitionFile")

  field(:triggered_by, 5,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "triggeredBy",
    enum: true
  )

  field(:git, 6, type: InternalApi.RepoProxy.CreateRequest.Git)
end

defmodule InternalApi.RepoProxy.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_id, 1, type: :string, json_name: "hookId")
  field(:workflow_id, 2, type: :string, json_name: "workflowId")
  field(:pipeline_id, 3, type: :string, json_name: "pipelineId")
end

defmodule InternalApi.RepoProxy.CreateBlankRequest.Git do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:reference, 1, type: :string)
  field(:commit_sha, 2, type: :string, json_name: "commitSha")
end

defmodule InternalApi.RepoProxy.CreateBlankRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:request_token, 1, type: :string, json_name: "requestToken")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:requester_id, 3, type: :string, json_name: "requesterId")
  field(:definition_file, 4, type: :string, json_name: "definitionFile")
  field(:pipeline_id, 5, type: :string, json_name: "pipelineId")
  field(:wf_id, 6, type: :string, json_name: "wfId")

  field(:triggered_by, 7,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "triggeredBy",
    enum: true
  )

  field(:git, 8, type: InternalApi.RepoProxy.CreateBlankRequest.Git)
end

defmodule InternalApi.RepoProxy.CreateBlankResponse.Repo do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:owner, 1, type: :string)
  field(:repo_name, 2, type: :string, json_name: "repoName")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:commit_sha, 4, type: :string, json_name: "commitSha")
  field(:repository_id, 5, type: :string, json_name: "repositoryId")
end

defmodule InternalApi.RepoProxy.CreateBlankResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:hook_id, 1, type: :string, json_name: "hookId")
  field(:wf_id, 2, type: :string, json_name: "wfId")
  field(:pipeline_id, 3, type: :string, json_name: "pipelineId")
  field(:branch_id, 4, type: :string, json_name: "branchId")
  field(:repo, 5, type: InternalApi.RepoProxy.CreateBlankResponse.Repo)
end

defmodule InternalApi.RepoProxy.PullRequestUnmergeable do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:branch_name, 2, type: :string, json_name: "branchName")
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.RepoProxy.RepoProxyService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.RepoProxy.RepoProxyService",
    protoc_gen_elixir_version: "0.12.0"

  rpc(:Describe, InternalApi.RepoProxy.DescribeRequest, InternalApi.RepoProxy.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.RepoProxy.DescribeManyRequest,
    InternalApi.RepoProxy.DescribeManyResponse
  )

  rpc(
    :ListBlockedHooks,
    InternalApi.RepoProxy.ListBlockedHooksRequest,
    InternalApi.RepoProxy.ListBlockedHooksResponse
  )

  rpc(
    :ScheduleBlockedHook,
    InternalApi.RepoProxy.ScheduleBlockedHookRequest,
    InternalApi.RepoProxy.ScheduleBlockedHookResponse
  )

  rpc(:Create, InternalApi.RepoProxy.CreateRequest, InternalApi.RepoProxy.CreateResponse)

  rpc(
    :CreateBlank,
    InternalApi.RepoProxy.CreateBlankRequest,
    InternalApi.RepoProxy.CreateBlankResponse
  )
end

defmodule InternalApi.RepoProxy.RepoProxyService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.RepoProxy.RepoProxyService.Service
end
