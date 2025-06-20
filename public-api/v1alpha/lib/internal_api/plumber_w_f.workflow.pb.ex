defmodule InternalApi.PlumberWF.ScheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service: integer,
          repo: InternalApi.PlumberWF.ScheduleRequest.Repo.t(),
          project_id: String.t(),
          branch_id: String.t(),
          hook_id: String.t(),
          request_token: String.t(),
          snapshot_id: String.t(),
          definition_file: String.t(),
          requester_id: String.t(),
          organization_id: String.t(),
          label: String.t(),
          triggered_by: integer,
          scheduler_task_id: String.t(),
          env_vars: [InternalApi.PlumberWF.ScheduleRequest.EnvVar.t()]
        }
  defstruct [
    :service,
    :repo,
    :project_id,
    :branch_id,
    :hook_id,
    :request_token,
    :snapshot_id,
    :definition_file,
    :requester_id,
    :organization_id,
    :label,
    :triggered_by,
    :scheduler_task_id,
    :env_vars
  ]

  field(:service, 2, type: InternalApi.PlumberWF.ScheduleRequest.ServiceType, enum: true)
  field(:repo, 3, type: InternalApi.PlumberWF.ScheduleRequest.Repo)
  field(:project_id, 6, type: :string)
  field(:branch_id, 7, type: :string)
  field(:hook_id, 8, type: :string)
  field(:request_token, 9, type: :string)
  field(:snapshot_id, 10, type: :string)
  field(:definition_file, 11, type: :string)
  field(:requester_id, 12, type: :string)
  field(:organization_id, 13, type: :string)
  field(:label, 14, type: :string)
  field(:triggered_by, 15, type: InternalApi.PlumberWF.TriggeredBy, enum: true)
  field(:scheduler_task_id, 16, type: :string)
  field(:env_vars, 17, repeated: true, type: InternalApi.PlumberWF.ScheduleRequest.EnvVar)
end

defmodule InternalApi.PlumberWF.ScheduleRequest.Repo do
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

  field(:owner, 1, type: :string)
  field(:repo_name, 2, type: :string)
  field(:branch_name, 4, type: :string)
  field(:commit_sha, 5, type: :string)
  field(:repository_id, 6, type: :string)
end

defmodule InternalApi.PlumberWF.ScheduleRequest.EnvVar do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }
  defstruct [:name, :value]

  field(:name, 1, type: :string)
  field(:value, 2, type: :string)
end

defmodule InternalApi.PlumberWF.ScheduleRequest.ServiceType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:GIT_HUB, 0)
  field(:LOCAL, 1)
  field(:SNAPSHOT, 2)
  field(:BITBUCKET, 3)
  field(:GITLAB, 4)
  field(:GIT, 5)
end

defmodule InternalApi.PlumberWF.ScheduleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          status: InternalApi.Status.t(),
          ppl_id: String.t()
        }
  defstruct [:wf_id, :status, :ppl_id]

  field(:wf_id, 2, type: :string)
  field(:status, 3, type: InternalApi.Status)
  field(:ppl_id, 4, type: :string)
end

defmodule InternalApi.PlumberWF.GetPathRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          first_ppl_id: String.t(),
          last_ppl_id: String.t()
        }
  defstruct [:wf_id, :first_ppl_id, :last_ppl_id]

  field(:wf_id, 1, type: :string)
  field(:first_ppl_id, 2, type: :string)
  field(:last_ppl_id, 3, type: :string)
end

defmodule InternalApi.PlumberWF.GetPathResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          wf_created_at: Google.Protobuf.Timestamp.t(),
          path: [InternalApi.PlumberWF.GetPathResponse.PathElement.t()],
          status: InternalApi.Status.t()
        }
  defstruct [:wf_id, :wf_created_at, :path, :status]

  field(:wf_id, 2, type: :string)
  field(:wf_created_at, 3, type: Google.Protobuf.Timestamp)
  field(:path, 4, repeated: true, type: InternalApi.PlumberWF.GetPathResponse.PathElement)
  field(:status, 5, type: InternalApi.Status)
end

defmodule InternalApi.PlumberWF.GetPathResponse.PathElement do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t(),
          switch_id: String.t(),
          rebuild_partition: [String.t()]
        }
  defstruct [:ppl_id, :switch_id, :rebuild_partition]

  field(:ppl_id, 1, type: :string)
  field(:switch_id, 2, type: :string)
  field(:rebuild_partition, 3, repeated: true, type: :string)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          order: integer,
          page_size: integer,
          page_token: String.t(),
          direction: integer,
          project_id: String.t(),
          requester_id: String.t(),
          git_ref_types: [integer]
        }
  defstruct [
    :order,
    :page_size,
    :page_token,
    :direction,
    :project_id,
    :requester_id,
    :git_ref_types
  ]

  field(:order, 1, type: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Order, enum: true)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)

  field(:direction, 4,
    type: InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction,
    enum: true
  )

  field(:project_id, 5, type: :string)
  field(:requester_id, 6, type: :string)
  field(:git_ref_types, 7, repeated: true, type: InternalApi.PlumberWF.GitRefType, enum: true)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ListLatestWorkflowsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:workflows, :next_page_token, :previous_page_token]

  field(:workflows, 1, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 2, type: :string)
  field(:previous_page_token, 3, type: :string)
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          order: integer,
          page_size: integer,
          page_token: String.t(),
          direction: integer,
          project_id: String.t(),
          requester_id: String.t(),
          git_ref_types: [integer]
        }
  defstruct [
    :order,
    :page_size,
    :page_token,
    :direction,
    :project_id,
    :requester_id,
    :git_ref_types
  ]

  field(:order, 1, type: InternalApi.PlumberWF.ListGroupedKSRequest.Order, enum: true)
  field(:page_size, 2, type: :int32)
  field(:page_token, 3, type: :string)
  field(:direction, 4, type: InternalApi.PlumberWF.ListGroupedKSRequest.Direction, enum: true)
  field(:project_id, 5, type: :string)
  field(:requester_id, 6, type: :string)
  field(:git_ref_types, 7, repeated: true, type: InternalApi.PlumberWF.GitRefType, enum: true)
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListGroupedKSRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ListGroupedKSResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:workflows, :next_page_token, :previous_page_token]

  field(:workflows, 1, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 2, type: :string)
  field(:previous_page_token, 3, type: :string)
end

defmodule InternalApi.PlumberWF.ListGroupedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer,
          project_id: String.t(),
          grouped_by: integer,
          git_ref_types: [integer]
        }
  defstruct [:page, :page_size, :project_id, :grouped_by, :git_ref_types]

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32)
  field(:project_id, 3, type: :string)
  field(:grouped_by, 4, type: InternalApi.PlumberWF.ListGroupedRequest.SourceType, enum: true)
  field(:git_ref_types, 5, repeated: true, type: InternalApi.PlumberWF.GitRefType, enum: true)
end

defmodule InternalApi.PlumberWF.ListGroupedRequest.SourceType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PULL_REQUEST, 2)
end

defmodule InternalApi.PlumberWF.ListGroupedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:status, :workflows, :page_number, :page_size, :total_entries, :total_pages]

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:page_number, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:total_entries, 5, type: :int32)
  field(:total_pages, 6, type: :int32)
end

defmodule InternalApi.PlumberWF.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer,
          project_id: String.t(),
          branch_name: String.t(),
          requester_id: String.t(),
          organization_id: String.t(),
          project_ids: [String.t()],
          created_before: Google.Protobuf.Timestamp.t(),
          created_after: Google.Protobuf.Timestamp.t(),
          label: String.t(),
          git_ref_types: [integer]
        }
  defstruct [
    :page,
    :page_size,
    :project_id,
    :branch_name,
    :requester_id,
    :organization_id,
    :project_ids,
    :created_before,
    :created_after,
    :label,
    :git_ref_types
  ]

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32)
  field(:project_id, 3, type: :string)
  field(:branch_name, 4, type: :string)
  field(:requester_id, 5, type: :string)
  field(:organization_id, 6, type: :string)
  field(:project_ids, 7, repeated: true, type: :string)
  field(:created_before, 8, type: Google.Protobuf.Timestamp)
  field(:created_after, 9, type: Google.Protobuf.Timestamp)
  field(:label, 10, type: :string)
  field(:git_ref_types, 11, repeated: true, type: InternalApi.PlumberWF.GitRefType, enum: true)
end

defmodule InternalApi.PlumberWF.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:status, :workflows, :page_number, :page_size, :total_entries, :total_pages]

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:page_number, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:total_entries, 5, type: :int32)
  field(:total_pages, 6, type: :int32)
end

defmodule InternalApi.PlumberWF.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          organization_id: String.t(),
          project_id: String.t(),
          requester_id: String.t(),
          project_ids: [String.t()],
          created_before: Google.Protobuf.Timestamp.t(),
          created_after: Google.Protobuf.Timestamp.t(),
          label: String.t(),
          git_ref_types: [integer],
          direction: integer,
          triggerers: [integer],
          branch_name: String.t(),
          requester_ids: [String.t()]
        }
  defstruct [
    :page_size,
    :page_token,
    :order,
    :organization_id,
    :project_id,
    :requester_id,
    :project_ids,
    :created_before,
    :created_after,
    :label,
    :git_ref_types,
    :direction,
    :triggerers,
    :branch_name,
    :requester_ids
  ]

  field(:page_size, 1, type: :int32)
  field(:page_token, 2, type: :string)
  field(:order, 3, type: InternalApi.PlumberWF.ListKeysetRequest.Order, enum: true)
  field(:organization_id, 4, type: :string)
  field(:project_id, 5, type: :string)
  field(:requester_id, 6, type: :string)
  field(:project_ids, 7, repeated: true, type: :string)
  field(:created_before, 8, type: Google.Protobuf.Timestamp)
  field(:created_after, 9, type: Google.Protobuf.Timestamp)
  field(:label, 10, type: :string)
  field(:git_ref_types, 11, repeated: true, type: InternalApi.PlumberWF.GitRefType, enum: true)
  field(:direction, 12, type: InternalApi.PlumberWF.ListKeysetRequest.Direction, enum: true)
  field(:triggerers, 13, repeated: true, type: InternalApi.PlumberWF.TriggeredBy, enum: true)
  field(:branch_name, 14, type: :string)
  field(:requester_ids, 15, repeated: true, type: :string)
end

defmodule InternalApi.PlumberWF.ListKeysetRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BY_CREATION_TIME_DESC, 0)
end

defmodule InternalApi.PlumberWF.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:NEXT, 0)
  field(:PREVIOUS, 1)
end

defmodule InternalApi.PlumberWF.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:status, :workflows, :next_page_token, :previous_page_token]

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
  field(:next_page_token, 3, type: :string)
  field(:previous_page_token, 4, type: :string)
end

defmodule InternalApi.PlumberWF.WorkflowDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          initial_ppl_id: String.t(),
          project_id: String.t(),
          hook_id: String.t(),
          requester_id: String.t(),
          branch_id: String.t(),
          branch_name: String.t(),
          commit_sha: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          triggered_by: integer,
          rerun_of: String.t(),
          repository_id: String.t(),
          organization_id: String.t()
        }
  defstruct [
    :wf_id,
    :initial_ppl_id,
    :project_id,
    :hook_id,
    :requester_id,
    :branch_id,
    :branch_name,
    :commit_sha,
    :created_at,
    :triggered_by,
    :rerun_of,
    :repository_id,
    :organization_id
  ]

  field(:wf_id, 1, type: :string)
  field(:initial_ppl_id, 2, type: :string)
  field(:project_id, 3, type: :string)
  field(:hook_id, 4, type: :string)
  field(:requester_id, 5, type: :string)
  field(:branch_id, 6, type: :string)
  field(:branch_name, 7, type: :string)
  field(:commit_sha, 8, type: :string)
  field(:created_at, 9, type: Google.Protobuf.Timestamp)
  field(:triggered_by, 10, type: InternalApi.PlumberWF.TriggeredBy, enum: true)
  field(:rerun_of, 11, type: :string)
  field(:repository_id, 12, type: :string)
  field(:organization_id, 13, type: :string)
end

defmodule InternalApi.PlumberWF.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t()
        }
  defstruct [:wf_id]

  field(:wf_id, 1, type: :string)
end

defmodule InternalApi.PlumberWF.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          workflow: InternalApi.PlumberWF.WorkflowDetails.t()
        }
  defstruct [:status, :workflow]

  field(:status, 1, type: InternalApi.Status)
  field(:workflow, 2, type: InternalApi.PlumberWF.WorkflowDetails)
end

defmodule InternalApi.PlumberWF.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_ids: [String.t()]
        }
  defstruct [:wf_ids]

  field(:wf_ids, 1, repeated: true, type: :string)
end

defmodule InternalApi.PlumberWF.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          workflows: [InternalApi.PlumberWF.WorkflowDetails.t()]
        }
  defstruct [:status, :workflows]

  field(:status, 1, type: InternalApi.Status)
  field(:workflows, 2, repeated: true, type: InternalApi.PlumberWF.WorkflowDetails)
end

defmodule InternalApi.PlumberWF.TerminateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requester_id: String.t(),
          wf_id: String.t()
        }
  defstruct [:requester_id, :wf_id]

  field(:requester_id, 2, type: :string)
  field(:wf_id, 3, type: :string)
end

defmodule InternalApi.PlumberWF.TerminateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t()
        }
  defstruct [:status]

  field(:status, 2, type: InternalApi.Status)
end

defmodule InternalApi.PlumberWF.ListLabelsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer,
          project_id: String.t()
        }
  defstruct [:page, :page_size, :project_id]

  field(:page, 1, type: :int32)
  field(:page_size, 2, type: :int32)
  field(:project_id, 3, type: :string)
end

defmodule InternalApi.PlumberWF.ListLabelsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          labels: [String.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:status, :labels, :page_number, :page_size, :total_entries, :total_pages]

  field(:status, 1, type: InternalApi.Status)
  field(:labels, 2, repeated: true, type: :string)
  field(:page_number, 3, type: :int32)
  field(:page_size, 4, type: :int32)
  field(:total_entries, 5, type: :int32)
  field(:total_pages, 6, type: :int32)
end

defmodule InternalApi.PlumberWF.RescheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          requester_id: String.t(),
          request_token: String.t()
        }
  defstruct [:wf_id, :requester_id, :request_token]

  field(:wf_id, 1, type: :string)
  field(:requester_id, 2, type: :string)
  field(:request_token, 3, type: :string)
end

defmodule InternalApi.PlumberWF.GetProjectIdRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t()
        }
  defstruct [:wf_id]

  field(:wf_id, 1, type: :string)
end

defmodule InternalApi.PlumberWF.GetProjectIdResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Status.t(),
          project_id: String.t()
        }
  defstruct [:status, :project_id]

  field(:status, 1, type: InternalApi.Status)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.PlumberWF.CreateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          label: String.t(),
          hook_id: String.t(),
          request_token: String.t(),
          definition_file: String.t(),
          requester_id: String.t()
        }
  defstruct [:project_id, :label, :hook_id, :request_token, :definition_file, :requester_id]

  field(:project_id, 1, type: :string)
  field(:label, 2, type: :string)
  field(:hook_id, 3, type: :string)
  field(:request_token, 4, type: :string)
  field(:definition_file, 5, type: :string)
  field(:requester_id, 6, type: :string)
end

defmodule InternalApi.PlumberWF.CreateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_id: String.t(),
          status: InternalApi.Status.t(),
          ppl_id: String.t()
        }
  defstruct [:wf_id, :status, :ppl_id]

  field(:wf_id, 1, type: :string)
  field(:status, 2, type: InternalApi.Status)
  field(:ppl_id, 3, type: :string)
end

defmodule InternalApi.PlumberWF.TriggeredBy do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:HOOK, 0)
  field(:SCHEDULE, 1)
  field(:API, 2)
  field(:MANUAL_RUN, 3)
end

defmodule InternalApi.PlumberWF.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:BRANCH, 0)
  field(:TAG, 1)
  field(:PR, 2)
end

defmodule InternalApi.PlumberWF.WorkflowService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.PlumberWF.WorkflowService"

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
