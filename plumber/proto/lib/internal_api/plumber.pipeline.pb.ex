defmodule InternalApi.Plumber.ScheduleRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          service: integer,
          repo: InternalApi.Plumber.ScheduleRequest.Repo.t(),
          auth: InternalApi.Plumber.ScheduleRequest.Auth.t(),
          project_id: String.t(),
          branch_id: String.t(),
          hook_id: String.t(),
          request_token: String.t(),
          snapshot_id: String.t(),
          definition_file: String.t()
        }
  defstruct [
    :service,
    :repo,
    :auth,
    :project_id,
    :branch_id,
    :hook_id,
    :request_token,
    :snapshot_id,
    :definition_file
  ]

  field :service, 2, type: InternalApi.Plumber.ScheduleRequest.ServiceType, enum: true
  field :repo, 3, type: InternalApi.Plumber.ScheduleRequest.Repo
  field :auth, 4, type: InternalApi.Plumber.ScheduleRequest.Auth
  field :project_id, 6, type: :string
  field :branch_id, 7, type: :string
  field :hook_id, 8, type: :string
  field :request_token, 9, type: :string
  field :snapshot_id, 10, type: :string
  field :definition_file, 11, type: :string
end

defmodule InternalApi.Plumber.ScheduleRequest.Repo do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          owner: String.t(),
          repo_name: String.t(),
          branch_name: String.t(),
          commit_sha: String.t()
        }
  defstruct [:owner, :repo_name, :branch_name, :commit_sha]

  field :owner, 1, type: :string
  field :repo_name, 2, type: :string
  field :branch_name, 4, type: :string
  field :commit_sha, 5, type: :string
end

defmodule InternalApi.Plumber.ScheduleRequest.Auth do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          client_id: String.t(),
          client_secret: String.t(),
          access_token: String.t()
        }
  defstruct [:client_id, :client_secret, :access_token]

  field :client_id, 1, type: :string
  field :client_secret, 2, type: :string
  field :access_token, 3, type: :string
end

defmodule InternalApi.Plumber.ScheduleRequest.ServiceType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :GIT_HUB, 0
  field :LOCAL, 1
  field :SNAPSHOT, 2
end

defmodule InternalApi.Plumber.ScheduleResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          ppl_id: String.t()
        }
  defstruct [:response_status, :ppl_id]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :ppl_id, 2, type: :string
end

defmodule InternalApi.Plumber.DescribeRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t(),
          detailed: boolean
        }
  defstruct [:ppl_id, :detailed]

  field :ppl_id, 1, type: :string
  field :detailed, 2, type: :bool
end

defmodule InternalApi.Plumber.DescribeResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          pipeline: InternalApi.Plumber.Pipeline.t(),
          blocks: [InternalApi.Plumber.Block.t()]
        }
  defstruct [:response_status, :pipeline, :blocks]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :pipeline, 3, type: InternalApi.Plumber.Pipeline
  field :blocks, 4, repeated: true, type: InternalApi.Plumber.Block
end

defmodule InternalApi.Plumber.Block do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          block_id: String.t(),
          name: String.t(),
          build_req_id: String.t(),
          state: integer,
          result: integer,
          result_reason: integer,
          error_description: String.t(),
          jobs: [InternalApi.Plumber.Block.Job.t()]
        }
  defstruct [
    :block_id,
    :name,
    :build_req_id,
    :state,
    :result,
    :result_reason,
    :error_description,
    :jobs
  ]

  field :block_id, 1, type: :string
  field :name, 2, type: :string
  field :build_req_id, 3, type: :string
  field :state, 4, type: InternalApi.Plumber.Block.State, enum: true
  field :result, 5, type: InternalApi.Plumber.Block.Result, enum: true
  field :result_reason, 6, type: InternalApi.Plumber.Block.ResultReason, enum: true
  field :error_description, 7, type: :string
  field :jobs, 8, repeated: true, type: InternalApi.Plumber.Block.Job
end

defmodule InternalApi.Plumber.Block.Job do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          index: non_neg_integer,
          job_id: String.t(),
          status: String.t(),
          result: String.t()
        }
  defstruct [:name, :index, :job_id, :status, :result]

  field :name, 1, type: :string
  field :index, 2, type: :uint32
  field :job_id, 3, type: :string
  field :status, 4, type: :string
  field :result, 5, type: :string
end

defmodule InternalApi.Plumber.Block.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :WAITING, 0
  field :RUNNING, 1
  field :STOPPING, 2
  field :DONE, 3
  field :INITIALIZING, 4
end

defmodule InternalApi.Plumber.Block.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :PASSED, 0
  field :STOPPED, 1
  field :CANCELED, 2
  field :FAILED, 3
end

defmodule InternalApi.Plumber.Block.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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

defmodule InternalApi.Plumber.DescribeManyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_ids: [String.t()]
        }
  defstruct [:ppl_ids]

  field :ppl_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.Plumber.DescribeManyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          pipelines: [InternalApi.Plumber.Pipeline.t()]
        }
  defstruct [:response_status, :pipelines]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
end

defmodule InternalApi.Plumber.DescribeTopologyRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t()
        }
  defstruct [:ppl_id]

  field :ppl_id, 1, type: :string
end

defmodule InternalApi.Plumber.DescribeTopologyResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Plumber.ResponseStatus.t(),
          blocks: [InternalApi.Plumber.DescribeTopologyResponse.Block.t()],
          after_pipeline: InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline.t()
        }
  defstruct [:status, :blocks, :after_pipeline]

  field :status, 1, type: InternalApi.Plumber.ResponseStatus
  field :blocks, 2, repeated: true, type: InternalApi.Plumber.DescribeTopologyResponse.Block
  field :after_pipeline, 3, type: InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline
end

defmodule InternalApi.Plumber.DescribeTopologyResponse.Block do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          jobs: [String.t()],
          dependencies: [String.t()]
        }
  defstruct [:name, :jobs, :dependencies]

  field :name, 1, type: :string
  field :jobs, 2, repeated: true, type: :string
  field :dependencies, 3, repeated: true, type: :string
end

defmodule InternalApi.Plumber.DescribeTopologyResponse.AfterPipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          jobs: [String.t()]
        }
  defstruct [:jobs]

  field :jobs, 1, repeated: true, type: :string
end

defmodule InternalApi.Plumber.TerminateRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t(),
          requester_id: String.t()
        }
  defstruct [:ppl_id, :requester_id]

  field :ppl_id, 1, type: :string
  field :requester_id, 2, type: :string
end

defmodule InternalApi.Plumber.TerminateResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t()
        }
  defstruct [:response_status]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
end

defmodule InternalApi.Plumber.ListQueuesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer,
          project_id: String.t(),
          organization_id: String.t(),
          queue_types: [integer]
        }
  defstruct [:page, :page_size, :project_id, :organization_id, :queue_types]

  field :page, 1, type: :int32
  field :page_size, 2, type: :int32
  field :project_id, 3, type: :string
  field :organization_id, 4, type: :string
  field :queue_types, 5, repeated: true, type: InternalApi.Plumber.QueueType, enum: true
end

defmodule InternalApi.Plumber.ListQueuesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          queues: [InternalApi.Plumber.Queue.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:response_status, :queues, :page_number, :page_size, :total_entries, :total_pages]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :queues, 2, repeated: true, type: InternalApi.Plumber.Queue
  field :page_number, 3, type: :int32
  field :page_size, 4, type: :int32
  field :total_entries, 5, type: :int32
  field :total_pages, 6, type: :int32
end

defmodule InternalApi.Plumber.ListGroupedRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: integer,
          page_size: integer,
          project_id: String.t(),
          organization_id: String.t(),
          queue_type: [integer]
        }
  defstruct [:page, :page_size, :project_id, :organization_id, :queue_type]

  field :page, 1, type: :int32
  field :page_size, 2, type: :int32
  field :project_id, 3, type: :string
  field :organization_id, 4, type: :string
  field :queue_type, 5, repeated: true, type: InternalApi.Plumber.QueueType, enum: true
end

defmodule InternalApi.Plumber.ListGroupedResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          pipelines: [InternalApi.Plumber.Pipeline.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:response_status, :pipelines, :page_number, :page_size, :total_entries, :total_pages]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
  field :page_number, 3, type: :int32
  field :page_size, 4, type: :int32
  field :total_entries, 5, type: :int32
  field :total_pages, 6, type: :int32
end

defmodule InternalApi.Plumber.ListKeysetRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          direction: integer,
          project_id: String.t(),
          yml_file_path: String.t(),
          wf_id: String.t(),
          created_before: Google.Protobuf.Timestamp.t(),
          created_after: Google.Protobuf.Timestamp.t(),
          done_before: Google.Protobuf.Timestamp.t(),
          done_after: Google.Protobuf.Timestamp.t(),
          label: String.t(),
          git_ref_types: [integer],
          queue_id: String.t(),
          pr_head_branch: String.t(),
          pr_target_branch: String.t()
        }
  defstruct [
    :page_size,
    :page_token,
    :order,
    :direction,
    :project_id,
    :yml_file_path,
    :wf_id,
    :created_before,
    :created_after,
    :done_before,
    :done_after,
    :label,
    :git_ref_types,
    :queue_id,
    :pr_head_branch,
    :pr_target_branch
  ]

  field :page_size, 1, type: :int32
  field :page_token, 2, type: :string
  field :order, 3, type: InternalApi.Plumber.ListKeysetRequest.Order, enum: true
  field :direction, 4, type: InternalApi.Plumber.ListKeysetRequest.Direction, enum: true
  field :project_id, 5, type: :string
  field :yml_file_path, 6, type: :string
  field :wf_id, 7, type: :string
  field :created_before, 8, type: Google.Protobuf.Timestamp
  field :created_after, 9, type: Google.Protobuf.Timestamp
  field :done_before, 10, type: Google.Protobuf.Timestamp
  field :done_after, 11, type: Google.Protobuf.Timestamp
  field :label, 12, type: :string
  field :git_ref_types, 13, repeated: true, type: InternalApi.Plumber.GitRefType, enum: true
  field :queue_id, 14, type: :string
  field :pr_head_branch, 15, type: :string
  field :pr_target_branch, 16, type: :string
end

defmodule InternalApi.Plumber.ListKeysetRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BY_CREATION_TIME_DESC, 0
end

defmodule InternalApi.Plumber.ListKeysetRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :NEXT, 0
  field :PREVIOUS, 1
end

defmodule InternalApi.Plumber.ListKeysetResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipelines: [InternalApi.Plumber.Pipeline.t()],
          next_page_token: String.t(),
          previous_page_token: String.t()
        }
  defstruct [:pipelines, :next_page_token, :previous_page_token]

  field :pipelines, 1, repeated: true, type: InternalApi.Plumber.Pipeline
  field :next_page_token, 2, type: :string
  field :previous_page_token, 3, type: :string
end

defmodule InternalApi.Plumber.ListRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          branch_name: String.t(),
          page: integer,
          page_size: integer,
          yml_file_path: String.t(),
          wf_id: String.t(),
          created_before: Google.Protobuf.Timestamp.t(),
          created_after: Google.Protobuf.Timestamp.t(),
          done_before: Google.Protobuf.Timestamp.t(),
          done_after: Google.Protobuf.Timestamp.t(),
          label: String.t(),
          git_ref_types: [integer],
          queue_id: String.t(),
          pr_head_branch: String.t(),
          pr_target_branch: String.t()
        }
  defstruct [
    :project_id,
    :branch_name,
    :page,
    :page_size,
    :yml_file_path,
    :wf_id,
    :created_before,
    :created_after,
    :done_before,
    :done_after,
    :label,
    :git_ref_types,
    :queue_id,
    :pr_head_branch,
    :pr_target_branch
  ]

  field :project_id, 1, type: :string
  field :branch_name, 2, type: :string
  field :page, 3, type: :int32
  field :page_size, 4, type: :int32
  field :yml_file_path, 5, type: :string
  field :wf_id, 6, type: :string
  field :created_before, 7, type: Google.Protobuf.Timestamp
  field :created_after, 8, type: Google.Protobuf.Timestamp
  field :done_before, 9, type: Google.Protobuf.Timestamp
  field :done_after, 10, type: Google.Protobuf.Timestamp
  field :label, 11, type: :string
  field :git_ref_types, 12, repeated: true, type: InternalApi.Plumber.GitRefType, enum: true
  field :queue_id, 13, type: :string
  field :pr_head_branch, 14, type: :string
  field :pr_target_branch, 15, type: :string
end

defmodule InternalApi.Plumber.ListResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          pipelines: [InternalApi.Plumber.Pipeline.t()],
          page_number: integer,
          page_size: integer,
          total_entries: integer,
          total_pages: integer
        }
  defstruct [:response_status, :pipelines, :page_number, :page_size, :total_entries, :total_pages]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :pipelines, 2, repeated: true, type: InternalApi.Plumber.Pipeline
  field :page_number, 3, type: :int32
  field :page_size, 4, type: :int32
  field :total_entries, 5, type: :int32
  field :total_pages, 6, type: :int32
end

defmodule InternalApi.Plumber.Queue do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          queue_id: String.t(),
          name: String.t(),
          scope: String.t(),
          project_id: String.t(),
          organization_id: String.t(),
          type: integer
        }
  defstruct [:queue_id, :name, :scope, :project_id, :organization_id, :type]

  field :queue_id, 1, type: :string
  field :name, 2, type: :string
  field :scope, 3, type: :string
  field :project_id, 4, type: :string
  field :organization_id, 5, type: :string
  field :type, 6, type: InternalApi.Plumber.QueueType, enum: true
end

defmodule InternalApi.Plumber.Pipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t(),
          name: String.t(),
          project_id: String.t(),
          branch_name: String.t(),
          commit_sha: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          pending_at: Google.Protobuf.Timestamp.t(),
          queuing_at: Google.Protobuf.Timestamp.t(),
          running_at: Google.Protobuf.Timestamp.t(),
          stopping_at: Google.Protobuf.Timestamp.t(),
          done_at: Google.Protobuf.Timestamp.t(),
          state: integer,
          result: integer,
          result_reason: integer,
          terminate_request: String.t(),
          hook_id: String.t(),
          branch_id: String.t(),
          error_description: String.t(),
          switch_id: String.t(),
          working_directory: String.t(),
          yaml_file_name: String.t(),
          terminated_by: String.t(),
          wf_id: String.t(),
          snapshot_id: String.t(),
          queue: InternalApi.Plumber.Queue.t(),
          promotion_of: String.t(),
          partial_rerun_of: String.t(),
          commit_message: String.t(),
          partially_rerun_by: String.t(),
          compile_task_id: String.t(),
          with_after_task: boolean,
          after_task_id: String.t(),
          repository_id: String.t(),
          env_vars: [InternalApi.Plumber.EnvVariable.t()],
          triggerer: InternalApi.Plumber.Triggerer.t(),
          organization_id: String.t()
        }
  defstruct [
    :ppl_id,
    :name,
    :project_id,
    :branch_name,
    :commit_sha,
    :created_at,
    :pending_at,
    :queuing_at,
    :running_at,
    :stopping_at,
    :done_at,
    :state,
    :result,
    :result_reason,
    :terminate_request,
    :hook_id,
    :branch_id,
    :error_description,
    :switch_id,
    :working_directory,
    :yaml_file_name,
    :terminated_by,
    :wf_id,
    :snapshot_id,
    :queue,
    :promotion_of,
    :partial_rerun_of,
    :commit_message,
    :partially_rerun_by,
    :compile_task_id,
    :with_after_task,
    :after_task_id,
    :repository_id,
    :env_vars,
    :triggerer,
    :organization_id
  ]

  field :ppl_id, 1, type: :string
  field :name, 2, type: :string
  field :project_id, 3, type: :string
  field :branch_name, 4, type: :string
  field :commit_sha, 5, type: :string
  field :created_at, 6, type: Google.Protobuf.Timestamp
  field :pending_at, 7, type: Google.Protobuf.Timestamp
  field :queuing_at, 8, type: Google.Protobuf.Timestamp
  field :running_at, 9, type: Google.Protobuf.Timestamp
  field :stopping_at, 10, type: Google.Protobuf.Timestamp
  field :done_at, 11, type: Google.Protobuf.Timestamp
  field :state, 12, type: InternalApi.Plumber.Pipeline.State, enum: true
  field :result, 13, type: InternalApi.Plumber.Pipeline.Result, enum: true
  field :result_reason, 14, type: InternalApi.Plumber.Pipeline.ResultReason, enum: true
  field :terminate_request, 15, type: :string
  field :hook_id, 16, type: :string
  field :branch_id, 17, type: :string
  field :error_description, 18, type: :string
  field :switch_id, 19, type: :string
  field :working_directory, 20, type: :string
  field :yaml_file_name, 21, type: :string
  field :terminated_by, 22, type: :string
  field :wf_id, 23, type: :string
  field :snapshot_id, 24, type: :string
  field :queue, 25, type: InternalApi.Plumber.Queue
  field :promotion_of, 26, type: :string
  field :partial_rerun_of, 27, type: :string
  field :commit_message, 28, type: :string
  field :partially_rerun_by, 29, type: :string
  field :compile_task_id, 30, type: :string
  field :with_after_task, 31, type: :bool
  field :after_task_id, 32, type: :string
  field :repository_id, 33, type: :string
  field :env_vars, 34, repeated: true, type: InternalApi.Plumber.EnvVariable
  field :triggerer, 35, type: InternalApi.Plumber.Triggerer
  field :organization_id, 36, type: :string
end

defmodule InternalApi.Plumber.Pipeline.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :INITIALIZING, 0
  field :PENDING, 1
  field :QUEUING, 2
  field :RUNNING, 3
  field :STOPPING, 4
  field :DONE, 5
end

defmodule InternalApi.Plumber.Pipeline.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :PASSED, 0
  field :STOPPED, 1
  field :CANCELED, 2
  field :FAILED, 3
end

defmodule InternalApi.Plumber.Pipeline.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

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

defmodule InternalApi.Plumber.Triggerer do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          wf_triggered_by: integer,
          wf_triggerer_id: String.t(),
          wf_triggerer_user_id: String.t(),
          wf_triggerer_provider_login: String.t(),
          wf_triggerer_provider_uid: String.t(),
          wf_triggerer_provider_avatar: String.t(),
          ppl_triggered_by: integer,
          ppl_triggerer_id: String.t(),
          ppl_triggerer_user_id: String.t(),
          workflow_rerun_of: String.t()
        }
  defstruct [
    :wf_triggered_by,
    :wf_triggerer_id,
    :wf_triggerer_user_id,
    :wf_triggerer_provider_login,
    :wf_triggerer_provider_uid,
    :wf_triggerer_provider_avatar,
    :ppl_triggered_by,
    :ppl_triggerer_id,
    :ppl_triggerer_user_id,
    :workflow_rerun_of
  ]

  field :wf_triggered_by, 1, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :wf_triggerer_id, 2, type: :string
  field :wf_triggerer_user_id, 3, type: :string
  field :wf_triggerer_provider_login, 4, type: :string
  field :wf_triggerer_provider_uid, 5, type: :string
  field :wf_triggerer_provider_avatar, 6, type: :string
  field :ppl_triggered_by, 7, type: InternalApi.Plumber.TriggeredBy, enum: true
  field :ppl_triggerer_id, 8, type: :string
  field :ppl_triggerer_user_id, 9, type: :string
  field :workflow_rerun_of, 10, type: :string
end

defmodule InternalApi.Plumber.ListActivityRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page_size: integer,
          page_token: String.t(),
          order: integer,
          organization_id: String.t(),
          direction: integer
        }
  defstruct [:page_size, :page_token, :order, :organization_id, :direction]

  field :page_size, 1, type: :int32
  field :page_token, 2, type: :string
  field :order, 3, type: InternalApi.Plumber.ListActivityRequest.Order, enum: true
  field :organization_id, 4, type: :string
  field :direction, 5, type: InternalApi.Plumber.ListActivityRequest.Direction, enum: true
end

defmodule InternalApi.Plumber.ListActivityRequest.Order do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BY_CREATION_TIME_DESC, 0
end

defmodule InternalApi.Plumber.ListActivityRequest.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :NEXT, 0
  field :PREVIOUS, 1
end

defmodule InternalApi.Plumber.ListActivityResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          next_page_token: String.t(),
          previous_page_token: String.t(),
          pipelines: [InternalApi.Plumber.ActivePipeline.t()]
        }
  defstruct [:next_page_token, :previous_page_token, :pipelines]

  field :next_page_token, 1, type: :string
  field :previous_page_token, 2, type: :string
  field :pipelines, 3, repeated: true, type: InternalApi.Plumber.ActivePipeline
end

defmodule InternalApi.Plumber.ListRequestersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          page_token: String.t(),
          page_size: integer,
          requested_at_gt: Google.Protobuf.Timestamp.t(),
          requested_at_lte: Google.Protobuf.Timestamp.t()
        }
  defstruct [:organization_id, :page_token, :page_size, :requested_at_gt, :requested_at_lte]

  field :organization_id, 1, type: :string
  field :page_token, 2, type: :string
  field :page_size, 3, type: :int32
  field :requested_at_gt, 4, type: Google.Protobuf.Timestamp
  field :requested_at_lte, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.ListRequestersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requesters: [InternalApi.Plumber.Requester.t()],
          next_page_token: String.t()
        }
  defstruct [:requesters, :next_page_token]

  field :requesters, 1, repeated: true, type: InternalApi.Plumber.Requester
  field :next_page_token, 2, type: :string
end

defmodule InternalApi.Plumber.Requester do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          ppl_id: String.t(),
          user_id: String.t(),
          provider_login: String.t(),
          provider_uid: String.t(),
          provider: integer,
          triggerer: integer,
          requested_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :organization_id,
    :project_id,
    :ppl_id,
    :user_id,
    :provider_login,
    :provider_uid,
    :provider,
    :triggerer,
    :requested_at
  ]

  field :organization_id, 1, type: :string
  field :project_id, 2, type: :string
  field :ppl_id, 3, type: :string
  field :user_id, 4, type: :string
  field :provider_login, 5, type: :string
  field :provider_uid, 6, type: :string
  field :provider, 7, type: InternalApi.User.RepositoryProvider.Type, enum: true
  field :triggerer, 8, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :requested_at, 9, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.ActivePipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          wf_id: String.t(),
          wf_number: non_neg_integer,
          name: String.t(),
          ppl_id: String.t(),
          hook_id: String.t(),
          switch_id: String.t(),
          definition_file: String.t(),
          priority: non_neg_integer,
          wf_triggered_by: integer,
          requester_id: String.t(),
          partial_rerun_of: String.t(),
          promotion_of: String.t(),
          promoter_id: String.t(),
          auto_promoted: boolean,
          git_ref: String.t(),
          commit_sha: String.t(),
          branch_id: String.t(),
          created_at: Google.Protobuf.Timestamp.t(),
          pending_at: Google.Protobuf.Timestamp.t(),
          queuing_at: Google.Protobuf.Timestamp.t(),
          running_at: Google.Protobuf.Timestamp.t(),
          queue: InternalApi.Plumber.Queue.t(),
          blocks: [InternalApi.Plumber.BlockDetails.t()],
          state: integer,
          git_ref_type: integer,
          commit_message: String.t(),
          commiter_username: String.t(),
          commiter_avatar_url: String.t(),
          triggerer: InternalApi.Plumber.Triggerer.t()
        }
  defstruct [
    :organization_id,
    :project_id,
    :wf_id,
    :wf_number,
    :name,
    :ppl_id,
    :hook_id,
    :switch_id,
    :definition_file,
    :priority,
    :wf_triggered_by,
    :requester_id,
    :partial_rerun_of,
    :promotion_of,
    :promoter_id,
    :auto_promoted,
    :git_ref,
    :commit_sha,
    :branch_id,
    :created_at,
    :pending_at,
    :queuing_at,
    :running_at,
    :queue,
    :blocks,
    :state,
    :git_ref_type,
    :commit_message,
    :commiter_username,
    :commiter_avatar_url,
    :triggerer
  ]

  field :organization_id, 1, type: :string
  field :project_id, 2, type: :string
  field :wf_id, 3, type: :string
  field :wf_number, 4, type: :uint32
  field :name, 5, type: :string
  field :ppl_id, 6, type: :string
  field :hook_id, 7, type: :string
  field :switch_id, 8, type: :string
  field :definition_file, 9, type: :string
  field :priority, 10, type: :uint32
  field :wf_triggered_by, 11, type: InternalApi.PlumberWF.TriggeredBy, enum: true
  field :requester_id, 12, type: :string
  field :partial_rerun_of, 13, type: :string
  field :promotion_of, 14, type: :string
  field :promoter_id, 15, type: :string
  field :auto_promoted, 16, type: :bool
  field :git_ref, 17, type: :string
  field :commit_sha, 18, type: :string
  field :branch_id, 19, type: :string
  field :created_at, 20, type: Google.Protobuf.Timestamp
  field :pending_at, 21, type: Google.Protobuf.Timestamp
  field :queuing_at, 22, type: Google.Protobuf.Timestamp
  field :running_at, 23, type: Google.Protobuf.Timestamp
  field :queue, 24, type: InternalApi.Plumber.Queue
  field :blocks, 25, repeated: true, type: InternalApi.Plumber.BlockDetails
  field :state, 26, type: InternalApi.Plumber.Pipeline.State, enum: true
  field :git_ref_type, 27, type: InternalApi.Plumber.GitRefType, enum: true
  field :commit_message, 28, type: :string
  field :commiter_username, 29, type: :string
  field :commiter_avatar_url, 30, type: :string
  field :triggerer, 31, type: InternalApi.Plumber.Triggerer
end

defmodule InternalApi.Plumber.BlockDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          block_id: String.t(),
          name: String.t(),
          priority: non_neg_integer,
          dependencies: [String.t()],
          state: integer,
          result: integer,
          result_reason: integer,
          error_description: String.t(),
          jobs: [InternalApi.Plumber.BlockDetails.JobDetails.t()]
        }
  defstruct [
    :block_id,
    :name,
    :priority,
    :dependencies,
    :state,
    :result,
    :result_reason,
    :error_description,
    :jobs
  ]

  field :block_id, 1, type: :string
  field :name, 2, type: :string
  field :priority, 3, type: :uint32
  field :dependencies, 4, repeated: true, type: :string
  field :state, 5, type: InternalApi.Plumber.Block.State, enum: true
  field :result, 6, type: InternalApi.Plumber.Block.Result, enum: true
  field :result_reason, 7, type: InternalApi.Plumber.Block.ResultReason, enum: true
  field :error_description, 8, type: :string
  field :jobs, 9, repeated: true, type: InternalApi.Plumber.BlockDetails.JobDetails
end

defmodule InternalApi.Plumber.BlockDetails.JobDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          index: non_neg_integer,
          status: String.t()
        }
  defstruct [:name, :index, :status]

  field :name, 1, type: :string
  field :index, 2, type: :uint32
  field :status, 3, type: :string
end

defmodule InternalApi.Plumber.RunNowRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          requester_id: String.t(),
          type: integer,
          ppl_id: String.t(),
          block_id: String.t(),
          job_id: String.t()
        }
  defstruct [:requester_id, :type, :ppl_id, :block_id, :job_id]

  field :requester_id, 1, type: :string
  field :type, 2, type: InternalApi.Plumber.RunNowRequest.Type, enum: true
  field :ppl_id, 3, type: :string
  field :block_id, 4, type: :string
  field :job_id, 5, type: :string
end

defmodule InternalApi.Plumber.RunNowRequest.Type do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :PIPELINE, 0
  field :BLOCK, 1
  field :JOB, 2
end

defmodule InternalApi.Plumber.RunNowResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Plumber.GetProjectIdRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t()
        }
  defstruct [:ppl_id]

  field :ppl_id, 1, type: :string
end

defmodule InternalApi.Plumber.GetProjectIdResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          project_id: String.t()
        }
  defstruct [:response_status, :project_id]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :project_id, 2, type: :string
end

defmodule InternalApi.Plumber.ValidateYamlRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          yaml_definition: String.t(),
          ppl_id: String.t()
        }
  defstruct [:yaml_definition, :ppl_id]

  field :yaml_definition, 1, type: :string
  field :ppl_id, 2, type: :string
end

defmodule InternalApi.Plumber.ValidateYamlResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          ppl_id: String.t()
        }
  defstruct [:response_status, :ppl_id]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :ppl_id, 2, type: :string
end

defmodule InternalApi.Plumber.ScheduleExtensionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          file_path: String.t(),
          ppl_id: String.t(),
          request_token: String.t(),
          env_variables: [InternalApi.Plumber.EnvVariable.t()],
          prev_ppl_artefact_ids: [String.t()],
          promoted_by: String.t(),
          auto_promoted: boolean,
          secret_names: [String.t()],
          deployment_target_id: String.t()
        }
  defstruct [
    :file_path,
    :ppl_id,
    :request_token,
    :env_variables,
    :prev_ppl_artefact_ids,
    :promoted_by,
    :auto_promoted,
    :secret_names,
    :deployment_target_id
  ]

  field :file_path, 1, type: :string
  field :ppl_id, 2, type: :string
  field :request_token, 3, type: :string
  field :env_variables, 4, repeated: true, type: InternalApi.Plumber.EnvVariable
  field :prev_ppl_artefact_ids, 6, repeated: true, type: :string
  field :promoted_by, 7, type: :string
  field :auto_promoted, 8, type: :bool
  field :secret_names, 9, repeated: true, type: :string
  field :deployment_target_id, 10, type: :string
end

defmodule InternalApi.Plumber.EnvVariable do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t()
        }
  defstruct [:name, :value]

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule InternalApi.Plumber.ScheduleExtensionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          ppl_id: String.t()
        }
  defstruct [:response_status, :ppl_id]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :ppl_id, 2, type: :string
end

defmodule InternalApi.Plumber.DeleteRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          requester: String.t()
        }
  defstruct [:project_id, :requester]

  field :project_id, 1, type: :string
  field :requester, 3, type: :string
end

defmodule InternalApi.Plumber.DeleteResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          status: InternalApi.Plumber.ResponseStatus.t()
        }
  defstruct [:status]

  field :status, 1, type: InternalApi.Plumber.ResponseStatus
end

defmodule InternalApi.Plumber.PartialRebuildRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ppl_id: String.t(),
          request_token: String.t(),
          user_id: String.t()
        }
  defstruct [:ppl_id, :request_token, :user_id]

  field :ppl_id, 1, type: :string
  field :request_token, 2, type: :string
  field :user_id, 3, type: :string
end

defmodule InternalApi.Plumber.PartialRebuildResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          response_status: InternalApi.Plumber.ResponseStatus.t(),
          ppl_id: String.t()
        }
  defstruct [:response_status, :ppl_id]

  field :response_status, 1, type: InternalApi.Plumber.ResponseStatus
  field :ppl_id, 2, type: :string
end

defmodule InternalApi.Plumber.VersionRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Plumber.VersionResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          version: String.t()
        }
  defstruct [:version]

  field :version, 1, type: :string
end

defmodule InternalApi.Plumber.ResponseStatus do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          code: integer,
          message: String.t()
        }
  defstruct [:code, :message]

  field :code, 1, type: InternalApi.Plumber.ResponseStatus.ResponseCode, enum: true
  field :message, 2, type: :string
end

defmodule InternalApi.Plumber.ResponseStatus.ResponseCode do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :OK, 0
  field :BAD_PARAM, 1
  field :LIMIT_EXCEEDED, 2
  field :REFUSED, 3
end

defmodule InternalApi.Plumber.PipelineEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          state: integer,
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:pipeline_id, :state, :timestamp]

  field :pipeline_id, 1, type: :string
  field :state, 2, type: InternalApi.Plumber.Pipeline.State, enum: true
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.PipelineBlockEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          block_id: String.t(),
          state: integer,
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:pipeline_id, :block_id, :state, :timestamp]

  field :pipeline_id, 1, type: :string
  field :block_id, 2, type: :string
  field :state, 3, type: InternalApi.Plumber.Block.State, enum: true
  field :timestamp, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.AfterPipeline do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          state: integer,
          result: integer,
          result_reason: integer,
          created_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [:pipeline_id, :state, :result, :result_reason, :created_at]

  field :pipeline_id, 1, type: :string
  field :state, 2, type: InternalApi.Plumber.AfterPipeline.State, enum: true
  field :result, 3, type: InternalApi.Plumber.AfterPipeline.Result, enum: true
  field :result_reason, 4, type: InternalApi.Plumber.AfterPipeline.ResultReason, enum: true
  field :created_at, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.AfterPipeline.State do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :WAITING, 0
  field :PENDING, 1
  field :RUNNING, 2
  field :DONE, 3
end

defmodule InternalApi.Plumber.AfterPipeline.Result do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :PASSED, 0
  field :STOPPED, 1
  field :FAILED, 2
end

defmodule InternalApi.Plumber.AfterPipeline.ResultReason do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :TEST, 0
  field :STUCK, 1
end

defmodule InternalApi.Plumber.AfterPipelineEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          state: integer,
          timestamp: Google.Protobuf.Timestamp.t()
        }
  defstruct [:pipeline_id, :state, :timestamp]

  field :pipeline_id, 1, type: :string
  field :state, 2, type: InternalApi.Plumber.AfterPipeline.State, enum: true
  field :timestamp, 3, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.PipelineDeleted do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          workflow_id: String.t(),
          organization_id: String.t(),
          project_id: String.t(),
          artifact_store_id: String.t(),
          deleted_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :pipeline_id,
    :workflow_id,
    :organization_id,
    :project_id,
    :artifact_store_id,
    :deleted_at
  ]

  field :pipeline_id, 1, type: :string
  field :workflow_id, 2, type: :string
  field :organization_id, 3, type: :string
  field :project_id, 4, type: :string
  field :artifact_store_id, 5, type: :string
  field :deleted_at, 6, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Plumber.QueueType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :IMPLICIT, 0
  field :USER_GENERATED, 1
end

defmodule InternalApi.Plumber.GitRefType do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :BRANCH, 0
  field :TAG, 1
  field :PR, 2
end

defmodule InternalApi.Plumber.TriggeredBy do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field :WORKFLOW, 0
  field :PROMOTION, 1
  field :AUTO_PROMOTION, 2
  field :PARTIAL_RE_RUN, 3
end

defmodule InternalApi.Plumber.PipelineService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Plumber.PipelineService"

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
