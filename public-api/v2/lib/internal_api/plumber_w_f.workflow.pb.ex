defmodule InternalApi.PlumberWF.TriggeredBy do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:HOOK, 0)
  field(:SCHEDULE, 1)
  field(:API, 2)
  field(:MANUAL_RUN, 3)
end

defmodule InternalApi.PlumberWF.GitRefType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.PlumberWF.ScheduleRequest.ServiceType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:GIT_HUB, 0)
  field(:LOCAL, 1)
  field(:SNAPSHOT, 2)
  field(:BITBUCKET, 3)
  field(:GITLAB, 4)
  field(:GIT, 5)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ListGroupedRequest.SourceType do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PULL_REQUEST, 2)
end

defmodule InternalApi.PlumberWF.ListKeysetRequest.Order do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListKeysetRequest.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ScheduleRequest.Repo do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:owner, 1, type: :string)
  field(:repo_name, 2, type: :string, json_name: "repoName")
  field(:branch_name, 4, type: :string, json_name: "branchName")
  field(:commit_sha, 5, type: :string, json_name: "commitSha")
  field(:repository_id, 6, type: :string, json_name: "repositoryId")
end

defmodule InternalApi.PlumberWF.ScheduleRequest.EnvVar do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.PlumberWF.ScheduleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:service, 2, type: InternalApi.PlumberWF.ScheduleRequest.ServiceType, enum: true)
  field(:repo, 3, type: InternalApi.PlumberWF.ScheduleRequest.Repo)
  field(:project_id, 6, type: :string, json_name: "projectId")
  field(:branch_id, 7, type: :string, json_name: "branchId")
  field(:hook_id, 8, type: :string, json_name: "hookId")
  field(:request_token, 9, type: :string, json_name: "requestToken")
  field(:snapshot_id, 10, type: :string, json_name: "snapshotId")
  field(:definition_file, 11, type: :string, json_name: "definitionFile")
  field(:requester_id, 12, type: :string, json_name: "requesterId")
  field(:organization_id, 13, type: :string, json_name: "organizationId")
  field(:label, 14, type: :string)

  field(:triggered_by, 15,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "triggeredBy",
    enum: true
  )

  field(:scheduler_task_id, 16, type: :string, json_name: "schedulerTaskId")

  field(:env_vars, 17,
    repeated: true,
    type: InternalApi.PlumberWF.ScheduleRequest.EnvVar,
    json_name: "envVars"
  )
end

defmodule InternalApi.PlumberWF.ScheduleResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 2, type: :string, json_name: "wfId")
  field(:status, 3, type: InternalApi.Status)
  field(:ppl_id, 4, type: :string, json_name: "pplId")
end

defmodule InternalApi.PlumberWF.GetPathRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
  field(:first_ppl_id, 2, type: :string, json_name: "firstPplId")
  field(:last_ppl_id, 3, type: :string, json_name: "lastPplId")
end

defmodule InternalApi.PlumberWF.GetPathResponse.PathElement do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:ppl_id, 1, type: :string, json_name: "pplId")
  field(:switch_id, 2, type: :string, json_name: "switchId")
  field(:rebuild_partition, 3, repeated: true, type: :string, json_name: "rebuildPartition")
end

defmodule InternalApi.PlumberWF.GetPathResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 2, type: :string, json_name: "wfId")
  field(:wf_created_at, 3, type: Google.Protobuf.Timestamp, json_name: "wfCreatedAt")
  field(:path, 4, repeated: true, type: InternalApi.PlumberWF.GetPathResponse.PathElement)
  field(:status, 5, type: InternalApi.Status)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:order, 1, type: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Order, enum: true)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")

  field(:direction, 4,
    type: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction,
    enum: true
  )

  field(:project_id, 5, type: :string, json_name: "projectId")
  field(:requester_id, 6, type: :string, json_name: "requesterId")

  field(:git_ref_types, 7,
    repeated: true,
    type: InternalApi.PlumberWF.GitRefType,
    json_name: "gitRefTypes",
    enum: true
  )
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:workflows, 1, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 3, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:order, 1, type: InternalApi.PlumberWF.ListGroupedKSRequest.Order, enum: true)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:page_token, 3, type: :string, json_name: "pageToken")
  field(:direction, 4, type: InternalApi.PlumberWF.ListGroupedKSRequest.Direction, enum: true)
  field(:project_id, 5, type: :string, json_name: "projectId")
  field(:requester_id, 6, type: :string, json_name: "requesterId")

  field(:git_ref_types, 7,
    repeated: true,
    type: InternalApi.PlumberWF.GitRefType,
    json_name: "gitRefTypes",
    enum: true
  )
end

defmodule InternalApi.PlumberWF.ListGroupedKSResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:workflows, 1, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 2, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 3, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.PlumberWF.ListGroupedRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:project_id, 3, type: :string, json_name: "projectId")

  field(:grouped_by, 4,
    type: InternalApi.PlumberWF.ListGroupedRequest.SourceType,
    json_name: "groupedBy",
    enum: true
  )

  field(:git_ref_types, 5,
    repeated: true,
    type: InternalApi.PlumberWF.GitRefType,
    json_name: "gitRefTypes",
    enum: true
  )
end

defmodule InternalApi.PlumberWF.ListGroupedResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:page_number, 3, type: :int32, json_name: "pageNumber")
  field(:page_size, 4, type: :int32, json_name: "pageSize")
  field(:total_entries, 5, type: :int32, json_name: "totalEntries")
  field(:total_pages, 6, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.PlumberWF.ListRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:branch_name, 4, type: :string, json_name: "branchName")
  field(:requester_id, 5, type: :string, json_name: "requesterId")
  field(:organization_id, 6, type: :string, json_name: "organizationId")
  field(:project_ids, 7, repeated: true, type: :string, json_name: "projectIds")
  field(:created_before, 8, type: Google.Protobuf.Timestamp, json_name: "createdBefore")
  field(:created_after, 9, type: Google.Protobuf.Timestamp, json_name: "createdAfter")
  field(:label, 10, type: :string)

  field(:git_ref_types, 11,
    repeated: true,
    type: InternalApi.PlumberWF.GitRefType,
    json_name: "gitRefTypes",
    enum: true
  )
end

defmodule InternalApi.PlumberWF.ListResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:page_number, 3, type: :int32, json_name: "pageNumber")
  field(:page_size, 4, type: :int32, json_name: "pageSize")
  field(:total_entries, 5, type: :int32, json_name: "totalEntries")
  field(:total_pages, 6, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.PlumberWF.ListKeysetRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page_size, 1, type: :int32, json_name: "pageSize")
  field(:page_token, 2, type: :string, json_name: "pageToken")
  field(:order, 3, type: InternalApi.PlumberWF.ListKeysetRequest.Order, enum: true)
  field(:organization_id, 4, type: :string, json_name: "organizationId")
  field(:project_id, 5, type: :string, json_name: "projectId")
  field(:requester_id, 6, type: :string, json_name: "requesterId")
  field(:project_ids, 7, repeated: true, type: :string, json_name: "projectIds")
  field(:created_before, 8, type: Google.Protobuf.Timestamp, json_name: "createdBefore")
  field(:created_after, 9, type: Google.Protobuf.Timestamp, json_name: "createdAfter")
  field(:label, 10, type: :string)

  field(:git_ref_types, 11,
    repeated: true,
    type: InternalApi.PlumberWF.GitRefType,
    json_name: "gitRefTypes",
    enum: true
  )

  field(:direction, 12, type: InternalApi.PlumberWF.ListKeysetRequest.Direction, enum: true)
  field(:triggerers, 13, repeated: true, type: InternalApi.PlumberWF.TriggeredBy, enum: true)
  field(:branch_name, 14, type: :string, json_name: "branchName")
  field(:requester_ids, 15, repeated: true, type: :string, json_name: "requesterIds")
end

defmodule InternalApi.PlumberWF.ListKeysetResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 3, type: :string, json_name: "nextPageToken")
  field(:previous_page_token, 4, type: :string, json_name: "previousPageToken")
end

defmodule InternalApi.PlumberWF.WorkflowDetails do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
  field(:initial_ppl_id, 2, type: :string, json_name: "initialPplId")
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:hook_id, 4, type: :string, json_name: "hookId")
  field(:requester_id, 5, type: :string, json_name: "requesterId")
  field(:branch_id, 6, type: :string, json_name: "branchId")
  field(:branch_name, 7, type: :string, json_name: "branchName")
  field(:commit_sha, 8, type: :string, json_name: "commitSha")
  field(:created_at, 9, type: Google.Protobuf.Timestamp, json_name: "createdAt")

  field(:triggered_by, 10,
    type: InternalApi.PlumberWF.TriggeredBy,
    json_name: "triggeredBy",
    enum: true
  )

  field(:rerun_of, 11, type: :string, json_name: "rerunOf")
  field(:repository_id, 12, type: :string, json_name: "repositoryId")
  field(:organization_id, 13, type: :string, json_name: "organizationId")
end

defmodule InternalApi.PlumberWF.DescribeRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
end

defmodule InternalApi.PlumberWF.DescribeResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:workflow, 2, type: InternalApi.PlumberWF.WorkflowDetails)
end

defmodule InternalApi.PlumberWF.DescribeManyRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_ids, 1, repeated: true, type: :string, json_name: "wfIds")
end

defmodule InternalApi.PlumberWF.DescribeManyResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
end

defmodule InternalApi.PlumberWF.TerminateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:requester_id, 2, type: :string, json_name: "requesterId")
  field(:wf_id, 3, type: :string, json_name: "wfId")
end

defmodule InternalApi.PlumberWF.TerminateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 2, type: InternalApi.Status)
end

defmodule InternalApi.PlumberWF.ListLabelsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32, json_name: "pageSize")
  field(:project_id, 3, type: :string, json_name: "projectId")
end

defmodule InternalApi.PlumberWF.ListLabelsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:labels, 2, repeated: true, type: :string)
  field(:page_number, 3, type: :int32, json_name: "pageNumber")
  field(:page_size, 4, type: :int32, json_name: "pageSize")
  field(:total_entries, 5, type: :int32, json_name: "totalEntries")
  field(:total_pages, 6, type: :int32, json_name: "totalPages")
end

defmodule InternalApi.PlumberWF.RescheduleRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
  field(:requester_id, 2, type: :string, json_name: "requesterId")
  field(:request_token, 3, type: :string, json_name: "requestToken")
end

defmodule InternalApi.PlumberWF.GetProjectIdRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
end

defmodule InternalApi.PlumberWF.GetProjectIdResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:status, 1, type: InternalApi.Status)
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.PlumberWF.CreateRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:label, 2, type: :string)
  field(:hook_id, 3, type: :string, json_name: "hookId")
  field(:request_token, 4, type: :string, json_name: "requestToken")
  field(:definition_file, 5, type: :string, json_name: "definitionFile")
  field(:requester_id, 6, type: :string, json_name: "requesterId")
end

defmodule InternalApi.PlumberWF.CreateResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.12.0"

  field(:wf_id, 1, type: :string, json_name: "wfId")
  field(:status, 2, type: InternalApi.Status)
  field(:ppl_id, 3, type: :string, json_name: "pplId")
end

defmodule InternalApi.PlumberWF.WorkflowService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.PlumberWF.WorkflowService",
    protoc_gen_elixir_version: "0.12.0"

  rpc(:Schedule, InternalApi.PlumberWF.ScheduleRequest, InternalApi.PlumberWF.ScheduleResponse)

  rpc(:GetPath, InternalApi.PlumberWF.GetPathRequest, InternalApi.PlumberWF.GetPathResponse)

  rpc(:List, InternalApi.PlumberWF.ListRequest, InternalApi.PlumberWF.ListResponse)

  rpc(
    :ListKeyset,
    InternalApi.PlumberWF.ListKeysetRequest,
    InternalApi.PlumberWF.ListKeysetResponse
  )

  rpc(
    :ListGrouped,
    InternalApi.PlumberWF.ListGroupedRequest,
    InternalApi.PlumberWF.ListGroupedResponse
  )

  rpc(
    :ListGroupedKS,
    InternalApi.PlumberWF.ListGroupedKSRequest,
    InternalApi.PlumberWF.ListGroupedKSResponse
  )

  rpc(
    :ListLatestWorkflows,
    InternalApi.PlumberWF.ListLatestWorkflowsRequest,
    InternalApi.PlumberWF.ListLatestWorkflowsResponse
  )

  rpc(:Describe, InternalApi.PlumberWF.DescribeRequest, InternalApi.PlumberWF.DescribeResponse)

  rpc(
    :DescribeMany,
    InternalApi.PlumberWF.DescribeManyRequest,
    InternalApi.PlumberWF.DescribeManyResponse
  )

  rpc(:Terminate, InternalApi.PlumberWF.TerminateRequest, InternalApi.PlumberWF.TerminateResponse)

  rpc(
    :ListLabels,
    InternalApi.PlumberWF.ListLabelsRequest,
    InternalApi.PlumberWF.ListLabelsResponse
  )

  rpc(
    :Reschedule,
    InternalApi.PlumberWF.RescheduleRequest,
    InternalApi.PlumberWF.ScheduleResponse
  )

  rpc(
    :GetProjectId,
    InternalApi.PlumberWF.GetProjectIdRequest,
    InternalApi.PlumberWF.GetProjectIdResponse
  )

  rpc(:Create, InternalApi.PlumberWF.CreateRequest, InternalApi.PlumberWF.CreateResponse)
end

defmodule InternalApi.PlumberWF.WorkflowService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.PlumberWF.WorkflowService.Service
end
