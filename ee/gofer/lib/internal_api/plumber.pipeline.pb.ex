defmodule InternalApi.Plumber.QueueType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :IMPLICIT, 0
  field :USER_GENERATED, 1
end

defmodule InternalApi.Plumber.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.Plumber.TriggeredBy do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :WORKFLOW, 0
  field :PROMOTION, 1
  field :AUTO_PROMOTION, 2
  field :PARTIAL_RE_RUN, 3
end

defmodule InternalApi.Plumber.ScheduleRequest.ServiceType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :GIT_HUB, 0
  field :LOCAL, 1
  field :SNAPSHOT, 2
end

defmodule InternalApi.Plumber.Block.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :WAITING, 0
  field :RUNNING, 1
  field :STOPPING, 2
  field :DONE, 3
  field :INITIALIZING, 4
end

defmodule InternalApi.Plumber.Block.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PASSED, 0
  field :STOPPED, 1
  field :CANCELED, 2
  field :FAILED, 3
end

defmodule InternalApi.Plumber.Block.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :TEST, 0
  field :MALFORMED, 1
  field :STUCK, 2
  field :USER, 3
  field :INTERNAL, 4
  field :STRATEGY, 5
  field :FAST_FAILING, 6
  field :DELETED, 7
  field :TIMEOUT, 8
  field :SKIPPED, 9
end

defmodule InternalApi.Plumber.ListKeysetRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BY_CREATION_TIME_DESC, 0
end

defmodule InternalApi.Plumber.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :NEXT, 0
  field :PREVIOUS, 1
end

defmodule InternalApi.Plumber.Pipeline.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :INITIALIZING, 0
  field :PENDING, 1
  field :QUEUING, 2
  field :RUNNING, 3
  field :STOPPING, 4
  field :DONE, 5
end

defmodule InternalApi.Plumber.Pipeline.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PASSED, 0
  field :STOPPED, 1
  field :CANCELED, 2
  field :FAILED, 3
end

defmodule InternalApi.Plumber.Pipeline.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :TEST, 0
  field :MALFORMED, 1
  field :STUCK, 2
  field :USER, 3
  field :INTERNAL, 4
  field :STRATEGY, 5
  field :FAST_FAILING, 6
  field :DELETED, 7
  field :TIMEOUT, 8
end

defmodule InternalApi.Plumber.ListActivityRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :BY_CREATION_TIME_DESC, 0
end

defmodule InternalApi.Plumber.ListActivityRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :NEXT, 0
  field :PREVIOUS, 1
end

defmodule InternalApi.Plumber.RunNowRequest.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PIPELINE, 0
  field :BLOCK, 1
  field :JOB, 2
end

defmodule InternalApi.Plumber.ResponseStatus.ResponseCode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :OK, 0
  field :BAD_PARAM, 1
  field :LIMIT_EXCEEDED, 2
  field :REFUSED, 3
end

defmodule InternalApi.Plumber.AfterPipeline.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :WAITING, 0
  field :PENDING, 1
  field :RUNNING, 2
  field :DONE, 3
end

defmodule InternalApi.Plumber.AfterPipeline.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :PASSED, 0
  field :STOPPED, 1
  field :FAILED, 2
end

defmodule InternalApi.Plumber.AfterPipeline.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :TEST, 0
  field :STUCK, 1
end

defmodule InternalApi.Plumber.ScheduleRequest.Repo do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :owner, 1, type: :string
  field :repo_name, 2, type: :string, json_name: "repoName"
  field :branch_name, 4, type: :string, json_name: "branchName"
  field :commit_sha, 5, type: :string, json_name: "commitSha"
end

defmodule InternalApi.Plumber.ScheduleRequest.Auth do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :client_id, 1, type: :string, json_name: "clientId"
  field :client_secret, 2, type: :string, json_name: "clientSecret"
  field :access_token, 3, type: :string, json_name: "accessToken"
end

defmodule InternalApi.Plumber.ScheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :service, 2, type: InternalApi.Plumber.ScheduleRequest.ServiceType, enum: true
  field :repo, 3, type: InternalApi.Plumber.ScheduleRequest.Repo
  field :auth, 4, type: InternalApi.Plumber.ScheduleRequest.Auth
  field :project_id, 6, type: :string, json_name: "projectId"
  field :branch_id, 7, type: :string, json_name: "branchId"
  field :hook_id, 8, type: :string, json_name: "hookId"
  field :request_token, 9, type: :string, json_name: "requestToken"
  field :snapshot_id, 10, type: :string, json_name: "snapshotId"
  field :definition_file, 11, type: :string, json_name: "definitionFile"
end

defmodule InternalApi.Plumber.ScheduleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :ppl_id, 2, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
  field :detailed, 2, type: :bool
end

defmodule InternalApi.Plumber.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :pipeline, 3, type: InternalApi.Plumber.Pipeline
  field :blocks, 4, repeated: true, type: InternalApi.Plumber.Block
end

defmodule InternalApi.Plumber.Block.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :index, 2, type: :uint32
  field :job_id, 3, type: :string, json_name: "jobId"
  field :status, 4, type: :string
  field :result, 5, type: :string
end

defmodule InternalApi.Plumber.Block do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :block_id, 1, type: :string, json_name: "blockId"
  field :name, 2, type: :string
  field :build_req_id, 3, type: :string, json_name: "buildReqId"
  field :state, 4, type: InternalApi.Plumber.Block.State, enum: true
  field :result, 5, type: InternalApi.Plumber.Block.Result, enum: true

  field :result_reason, 6,
    type: InternalApi.Plumber.Block.ResultReason,
    json_name: "resultReason",
    enum: true

  field :error_description, 7, type: :string, json_name: "errorDescription"
  field :jobs, 8, repeated: true, type: InternalApi.Plumber.Block.Job
end

defmodule InternalApi.Plumber.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_ids, 1, repeated: true, type: :string, json_name: "pplIds"
end

defmodule InternalApi.Plumber.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
end

defmodule InternalApi.Plumber.DescribeTopologyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.DescribeTopologyResponse.Block do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :jobs, 2, repeated: true, type: :string
  field :dependencies, 3, repeated: true, type: :string
end

defmodule InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :jobs, 1, repeated: true, type: :string
end

defmodule InternalApi.Plumber.DescribeTopologyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :status, 1, type: InternalApi.Plumber.ResponseStatus
  field :blocks, 2, repeated: true, type: InternalApi.Plumber.DescribeTopologyResponse.Block

  field :after_pipeline, 3,
    type: InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline,
    json_name: "afterPipeline"
end

defmodule InternalApi.Plumber.TerminateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
  field :requester_id, 2, type: :string, json_name: "requesterId"
end

defmodule InternalApi.Plumber.TerminateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
end

defmodule InternalApi.Plumber.ListQueuesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page, 1, type: :int32
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :project_id, 3, type: :string, json_name: "projectId"
  field :organization_id, 4, type: :string, json_name: "organizationId"

  field :queue_types, 5,
    repeated: true,
    type: InternalApi.Plumber.QueueType,
    json_name: "queueTypes",
    enum: true
end

defmodule InternalApi.Plumber.ListQueuesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :queues, 2, repeated: true, type: InternalApi.Plumber.Queue
  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Plumber.ListGroupedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page, 1, type: :int32
  field :page_size, 2, type: :int32, json_name: "pageSize"
  field :project_id, 3, type: :string, json_name: "projectId"
  field :organization_id, 4, type: :string, json_name: "organizationId"

  field :queue_type, 5,
    repeated: true,
    type: InternalApi.Plumber.QueueType,
    json_name: "queueType",
    enum: true
end

defmodule InternalApi.Plumber.ListGroupedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Plumber.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page_size, 1, type: :int32, json_name: "pageSize"
  field :page_token, 2, type: :string, json_name: "pageToken"
  field :order, 3, type: InternalApi.Plumber.ListKeysetRequest.Order, enum: true
  field :direction, 4, type: InternalApi.Plumber.ListKeysetRequest.Direction, enum: true
  field :project_id, 5, type: :string, json_name: "projectId"
  field :yml_file_path, 6, type: :string, json_name: "ymlFilePath"
  field :wf_id, 7, type: :string, json_name: "wfId"
  field :created_before, 8, type: Google.Protobuf.Timestamp, json_name: "createdBefore"
  field :created_after, 9, type: Google.Protobuf.Timestamp, json_name: "createdAfter"
  field :done_before, 10, type: Google.Protobuf.Timestamp, json_name: "doneBefore"
  field :done_after, 11, type: Google.Protobuf.Timestamp, json_name: "doneAfter"
  field :label, 12, type: :string

  field :git_ref_types, 13,
    repeated: true,
    type: InternalApi.Plumber.GitRefType,
    json_name: "gitRefTypes",
    enum: true

  field :queue_id, 14, type: :string, json_name: "queueId"
  field :pr_head_branch, 15, type: :string, json_name: "prHeadBranch"
  field :pr_target_branch, 16, type: :string, json_name: "prTargetBranch"
end

defmodule InternalApi.Plumber.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipelines, 1, repeated: true, type: InternalApi.Plumber.Pipeline
  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
  field :previous_page_token, 3, type: :string, json_name: "previousPageToken"
end

defmodule InternalApi.Plumber.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :branch_name, 2, type: :string, json_name: "branchName"
  field :page, 3, type: :int32
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :yml_file_path, 5, type: :string, json_name: "ymlFilePath"
  field :wf_id, 6, type: :string, json_name: "wfId"
  field :created_before, 7, type: Google.Protobuf.Timestamp, json_name: "createdBefore"
  field :created_after, 8, type: Google.Protobuf.Timestamp, json_name: "createdAfter"
  field :done_before, 9, type: Google.Protobuf.Timestamp, json_name: "doneBefore"
  field :done_after, 10, type: Google.Protobuf.Timestamp, json_name: "doneAfter"
  field :label, 11, type: :string

  field :git_ref_types, 12,
    repeated: true,
    type: InternalApi.Plumber.GitRefType,
    json_name: "gitRefTypes",
    enum: true

  field :queue_id, 13, type: :string, json_name: "queueId"
  field :pr_head_branch, 14, type: :string, json_name: "prHeadBranch"
  field :pr_target_branch, 15, type: :string, json_name: "prTargetBranch"
end

defmodule InternalApi.Plumber.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
  field :page_number, 3, type: :int32, json_name: "pageNumber"
  field :page_size, 4, type: :int32, json_name: "pageSize"
  field :total_entries, 5, type: :int32, json_name: "totalEntries"
  field :total_pages, 6, type: :int32, json_name: "totalPages"
end

defmodule InternalApi.Plumber.Queue do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :queue_id, 1, type: :string, json_name: "queueId"
  field :name, 2, type: :string
  field :scope, 3, type: :string
  field :project_id, 4, type: :string, json_name: "projectId"
  field :organization_id, 5, type: :string, json_name: "organizationId"
  field :type, 6, type: InternalApi.Plumber.QueueType, enum: true
end

defmodule InternalApi.Plumber.Pipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
  field :name, 2, type: :string
  field :project_id, 3, type: :string, json_name: "projectId"
  field :branch_name, 4, type: :string, json_name: "branchName"
  field :commit_sha, 5, type: :string, json_name: "commitSha"
  field :created_at, 6, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :pending_at, 7, type: Google.Protobuf.Timestamp, json_name: "pendingAt"
  field :queuing_at, 8, type: Google.Protobuf.Timestamp, json_name: "queuingAt"
  field :running_at, 9, type: Google.Protobuf.Timestamp, json_name: "runningAt"
  field :stopping_at, 10, type: Google.Protobuf.Timestamp, json_name: "stoppingAt"
  field :done_at, 11, type: Google.Protobuf.Timestamp, json_name: "doneAt"
  field :state, 12, type: InternalApi.Plumber.Pipeline.State, enum: true
  field :result, 13, type: InternalApi.Plumber.Pipeline.Result, enum: true

  field :result_reason, 14,
    type: InternalApi.Plumber.Pipeline.ResultReason,
    json_name: "resultReason",
    enum: true

  field :terminate_request, 15, type: :string, json_name: "terminateRequest"
  field :hook_id, 16, type: :string, json_name: "hookId"
  field :branch_id, 17, type: :string, json_name: "branchId"
  field :error_description, 18, type: :string, json_name: "errorDescription"
  field :switch_id, 19, type: :string, json_name: "switchId"
  field :working_directory, 20, type: :string, json_name: "workingDirectory"
  field :yaml_file_name, 21, type: :string, json_name: "yamlFileName"
  field :terminated_by, 22, type: :string, json_name: "terminatedBy"
  field :wf_id, 23, type: :string, json_name: "wfId"
  field :snapshot_id, 24, type: :string, json_name: "snapshotId"
  field :queue, 25, type: InternalApi.Plumber.Queue
  field :promotion_of, 26, type: :string, json_name: "promotionOf"
  field :partial_rerun_of, 27, type: :string, json_name: "partialRerunOf"
  field :commit_message, 28, type: :string, json_name: "commitMessage"
  field :partially_rerun_by, 29, type: :string, json_name: "partiallyRerunBy"
  field :compile_task_id, 30, type: :string, json_name: "compileTaskId"
  field :with_after_task, 31, type: :bool, json_name: "withAfterTask"
  field :after_task_id, 32, type: :string, json_name: "afterTaskId"
  field :repository_id, 33, type: :string, json_name: "repositoryId"
  field :env_vars, 34, repeated: true, type: InternalApi.Plumber.EnvVariable, json_name: "envVars"
  field :triggerer, 35, type: InternalApi.Plumber.Triggerer
  field :organization_id, 36, type: :string, json_name: "organizationId"
end

defmodule InternalApi.Plumber.Triggerer do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :wf_triggered_by, 1,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "wfTriggeredBy",
    enum: true

  field :wf_triggerer_id, 2, type: :string, json_name: "wfTriggererId"
  field :wf_triggerer_user_id, 3, type: :string, json_name: "wfTriggererUserId"
  field :wf_triggerer_provider_login, 4, type: :string, json_name: "wfTriggererProviderLogin"
  field :wf_triggerer_provider_uid, 5, type: :string, json_name: "wfTriggererProviderUid"
  field :wf_triggerer_provider_avatar, 6, type: :string, json_name: "wfTriggererProviderAvatar"

  field :ppl_triggered_by, 7,
    type: InternalApi.Plumber.TriggeredBy,
    json_name: "pplTriggeredBy",
    enum: true

  field :ppl_triggerer_id, 8, type: :string, json_name: "pplTriggererId"
  field :ppl_triggerer_user_id, 9, type: :string, json_name: "pplTriggererUserId"
  field :workflow_rerun_of, 10, type: :string, json_name: "workflowRerunOf"
end

defmodule InternalApi.Plumber.ListActivityRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :page_size, 1, type: :int32, json_name: "pageSize"
  field :page_token, 2, type: :string, json_name: "pageToken"
  field :order, 3, type: InternalApi.Plumber.ListActivityRequest.Order, enum: true
  field :organization_id, 4, type: :string, json_name: "organizationId"
  field :direction, 5, type: InternalApi.Plumber.ListActivityRequest.Direction, enum: true
end

defmodule InternalApi.Plumber.ListActivityResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :next_page_token, 1, type: :string, json_name: "nextPageToken"
  field :previous_page_token, 2, type: :string, json_name: "previousPageToken"
  field :pipelines, 3, repeated: true, type: InternalApi.Plumber.ActivePipeline
end

defmodule InternalApi.Plumber.ListRequestersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :page_token, 2, type: :string, json_name: "pageToken"
  field :page_size, 3, type: :int32, json_name: "pageSize"
  field :requested_at_gt, 4, type: Google.Protobuf.Timestamp, json_name: "requestedAtGt"
  field :requested_at_lte, 5, type: Google.Protobuf.Timestamp, json_name: "requestedAtLte"
end

defmodule InternalApi.Plumber.ListRequestersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :requesters, 1, repeated: true, type: InternalApi.Plumber.Requester
  field :next_page_token, 2, type: :string, json_name: "nextPageToken"
end

defmodule InternalApi.Plumber.Requester do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :ppl_id, 3, type: :string, json_name: "pplId"
  field :user_id, 4, type: :string, json_name: "userId"
  field :provider_login, 5, type: :string, json_name: "providerLogin"
  field :provider_uid, 6, type: :string, json_name: "providerUid"
  field :provider, 7, type: InternalApi.User.RepositoryProvider.Type, enum: true
  field :triggerer, 8, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :requested_at, 9, type: Google.Protobuf.Timestamp, json_name: "requestedAt"
end

defmodule InternalApi.Plumber.ActivePipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :organization_id, 1, type: :string, json_name: "organizationId"
  field :project_id, 2, type: :string, json_name: "projectId"
  field :wf_id, 3, type: :string, json_name: "wfId"
  field :wf_number, 4, type: :uint32, json_name: "wfNumber"
  field :name, 5, type: :string
  field :ppl_id, 6, type: :string, json_name: "pplId"
  field :hook_id, 7, type: :string, json_name: "hookId"
  field :switch_id, 8, type: :string, json_name: "switchId"
  field :definition_file, 9, type: :string, json_name: "definitionFile"
  field :priority, 10, type: :uint32

  field :wf_triggered_by, 11,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "wfTriggeredBy",
    enum: true

  field :requester_id, 12, type: :string, json_name: "requesterId"
  field :partial_rerun_of, 13, type: :string, json_name: "partialRerunOf"
  field :promotion_of, 14, type: :string, json_name: "promotionOf"
  field :promoter_id, 15, type: :string, json_name: "promoterId"
  field :auto_promoted, 16, type: :bool, json_name: "autoPromoted"
  field :git_ref, 17, type: :string, json_name: "gitRef"
  field :commit_sha, 18, type: :string, json_name: "commitSha"
  field :branch_id, 19, type: :string, json_name: "branchId"
  field :created_at, 20, type: Google.Protobuf.Timestamp, json_name: "createdAt"
  field :pending_at, 21, type: Google.Protobuf.Timestamp, json_name: "pendingAt"
  field :queuing_at, 22, type: Google.Protobuf.Timestamp, json_name: "queuingAt"
  field :running_at, 23, type: Google.Protobuf.Timestamp, json_name: "runningAt"
  field :queue, 24, type: InternalApi.Plumber.Queue
  field :blocks, 25, repeated: true, type: InternalApi.Plumber.BlockDetails
  field :state, 26, type: InternalApi.Plumber.Pipeline.State, enum: true

  field :git_ref_type, 27,
    type: InternalApi.Plumber.GitRefType,
    json_name: "gitRefType",
    enum: true

  field :commit_message, 28, type: :string, json_name: "commitMessage"
  field :commiter_username, 29, type: :string, json_name: "commiterUsername"
  field :commiter_avatar_url, 30, type: :string, json_name: "commiterAvatarUrl"
  field :triggerer, 31, type: InternalApi.Plumber.Triggerer
end

defmodule InternalApi.Plumber.BlockDetails.JobDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :index, 2, type: :uint32
  field :status, 3, type: :string
end

defmodule InternalApi.Plumber.BlockDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :block_id, 1, type: :string, json_name: "blockId"
  field :name, 2, type: :string
  field :priority, 3, type: :uint32
  field :dependencies, 4, repeated: true, type: :string
  field :state, 5, type: InternalApi.Plumber.Block.State, enum: true
  field :result, 6, type: InternalApi.Plumber.Block.Result, enum: true

  field :result_reason, 7,
    type: InternalApi.Plumber.Block.ResultReason,
    json_name: "resultReason",
    enum: true

  field :error_description, 8, type: :string, json_name: "errorDescription"
  field :jobs, 9, repeated: true, type: InternalApi.Plumber.BlockDetails.JobDetails
end

defmodule InternalApi.Plumber.RunNowRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :requester_id, 1, type: :string, json_name: "requesterId"
  field :type, 2, type: InternalApi.Plumber.RunNowRequest.Type, enum: true
  field :ppl_id, 3, type: :string, json_name: "pplId"
  field :block_id, 4, type: :string, json_name: "blockId"
  field :job_id, 5, type: :string, json_name: "jobId"
end

defmodule InternalApi.Plumber.RunNowResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"
end

defmodule InternalApi.Plumber.GetProjectIdRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.GetProjectIdResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :project_id, 2, type: :string, json_name: "projectId"
end

defmodule InternalApi.Plumber.ValidateYamlRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :yaml_definition, 1, type: :string, json_name: "yamlDefinition"
  field :ppl_id, 2, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.ValidateYamlResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :ppl_id, 2, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.ScheduleExtensionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :file_path, 1, type: :string, json_name: "filePath"
  field :ppl_id, 2, type: :string, json_name: "pplId"
  field :request_token, 3, type: :string, json_name: "requestToken"

  field :env_variables, 4,
    repeated: true,
    type: InternalApi.Plumber.EnvVariable,
    json_name: "envVariables"

  field :prev_ppl_artefact_ids, 6, repeated: true, type: :string, json_name: "prevPplArtefactIds"
  field :promoted_by, 7, type: :string, json_name: "promotedBy"
  field :auto_promoted, 8, type: :bool, json_name: "autoPromoted"
  field :secret_names, 9, repeated: true, type: :string, json_name: "secretNames"
  field :deployment_target_id, 10, type: :string, json_name: "deploymentTargetId"
end

defmodule InternalApi.Plumber.EnvVariable do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Plumber.ScheduleExtensionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :ppl_id, 2, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :project_id, 1, type: :string, json_name: "projectId"
  field :requester, 3, type: :string
end

defmodule InternalApi.Plumber.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :status, 1, type: InternalApi.Plumber.ResponseStatus
end

defmodule InternalApi.Plumber.PartialRebuildRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :ppl_id, 1, type: :string, json_name: "pplId"
  field :request_token, 2, type: :string, json_name: "requestToken"
  field :user_id, 3, type: :string, json_name: "userId"
end

defmodule InternalApi.Plumber.PartialRebuildResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus, json_name: "responseStatus"
  field :ppl_id, 2, type: :string, json_name: "pplId"
end

defmodule InternalApi.Plumber.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"
end

defmodule InternalApi.Plumber.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :version, 1, type: :string
end

defmodule InternalApi.Plumber.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :code, 1, type: InternalApi.Plumber.ResponseStatus.ResponseCode, enum: true
  field :message, 2, type: :string
end

defmodule InternalApi.Plumber.PipelineEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipeline_id, 1, type: :string, json_name: "pipelineId"
  field :state, 2, type: InternalApi.Plumber.Pipeline.State, enum: true
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.PipelineBlockEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipeline_id, 1, type: :string, json_name: "pipelineId"
  field :block_id, 2, type: :string, json_name: "blockId"
  field :state, 3, type: InternalApi.Plumber.Block.State, enum: true
  field :timestamp, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.AfterPipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipeline_id, 1, type: :string, json_name: "pipelineId"
  field :state, 2, type: InternalApi.Plumber.AfterPipeline.State, enum: true
  field :result, 3, type: InternalApi.Plumber.AfterPipeline.Result, enum: true

  field :result_reason, 4,
    type: InternalApi.Plumber.AfterPipeline.ResultReason,
    json_name: "resultReason",
    enum: true

  field :created_at, 5, type: Google.Protobuf.Timestamp, json_name: "createdAt"
end

defmodule InternalApi.Plumber.AfterPipelineEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.10.0"

  field :pipeline_id, 1, type: :string, json_name: "pipelineId"
  field :state, 2, type: InternalApi.Plumber.AfterPipeline.State, enum: true
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.PipelineService.Service do
  @moduledoc false
  use GRPC.Service,
    name: "InternalApi.Plumber.PipelineService",
    protoc_gen_elixir_version: "0.10.0"

  rpc :Schedule, InternalApi.Plumber.ScheduleRequest, InternalApi.Plumber.ScheduleResponse

  rpc :Describe, InternalApi.Plumber.DescribeRequest, InternalApi.Plumber.DescribeResponse

  rpc :DescribeMany,
      InternalApi.Plumber.DescribeManyRequest,
      InternalApi.Plumber.DescribeManyResponse

  rpc :DescribeTopology,
      InternalApi.Plumber.DescribeTopologyRequest,
      InternalApi.Plumber.DescribeTopologyResponse

  rpc :Terminate, InternalApi.Plumber.TerminateRequest, InternalApi.Plumber.TerminateResponse

  rpc :ListKeyset, InternalApi.Plumber.ListKeysetRequest, InternalApi.Plumber.ListKeysetResponse

  rpc :List, InternalApi.Plumber.ListRequest, InternalApi.Plumber.ListResponse

  rpc :ListGrouped,
      InternalApi.Plumber.ListGroupedRequest,
      InternalApi.Plumber.ListGroupedResponse

  rpc :ListQueues, InternalApi.Plumber.ListQueuesRequest, InternalApi.Plumber.ListQueuesResponse

  rpc :ListActivity,
      InternalApi.Plumber.ListActivityRequest,
      InternalApi.Plumber.ListActivityResponse

  rpc :ListRequesters,
      InternalApi.Plumber.ListRequestersRequest,
      InternalApi.Plumber.ListRequestersResponse

  rpc :RunNow, InternalApi.Plumber.RunNowRequest, InternalApi.Plumber.RunNowResponse

  rpc :GetProjectId,
      InternalApi.Plumber.GetProjectIdRequest,
      InternalApi.Plumber.GetProjectIdResponse

  rpc :ValidateYaml,
      InternalApi.Plumber.ValidateYamlRequest,
      InternalApi.Plumber.ValidateYamlResponse

  rpc :ScheduleExtension,
      InternalApi.Plumber.ScheduleExtensionRequest,
      InternalApi.Plumber.ScheduleExtensionResponse

  rpc :Delete, InternalApi.Plumber.DeleteRequest, InternalApi.Plumber.DeleteResponse

  rpc :PartialRebuild,
      InternalApi.Plumber.PartialRebuildRequest,
      InternalApi.Plumber.PartialRebuildResponse

  rpc :Version, InternalApi.Plumber.VersionRequest, InternalApi.Plumber.VersionResponse
end

defmodule InternalApi.Plumber.PipelineService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Plumber.PipelineService.Service
end
