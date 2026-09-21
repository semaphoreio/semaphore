defmodule InternalApi.Superjerry.Pagination do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          page: non_neg_integer,
          page_size: non_neg_integer
        }
  defstruct [:page, :page_size]

  field(:page, 1, type: :uint32)
  field(:page_size, 2, type: :uint32)
end

defmodule InternalApi.Superjerry.Sort do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dir: integer,
          name: String.t()
        }
  defstruct [:dir, :name]

  field(:dir, 1, type: InternalApi.Superjerry.Sort.Direction, enum: true)
  field(:name, 2, type: :string)
end

defmodule InternalApi.Superjerry.Sort.Direction do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  field(:ASC, 0)
  field(:DESC, 1)
end

defmodule InternalApi.Superjerry.Flaky do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          test_id: String.t(),
          test_name: String.t(),
          test_group: String.t(),
          test_runner: String.t(),
          test_file: String.t(),
          test_suite: String.t(),
          pass_rate: integer,
          labels: [String.t()],
          disruptions_count: integer,
          latest_disruption_at: Google.Protobuf.Timestamp.t(),
          first_disruption_at: Google.Protobuf.Timestamp.t(),
          latest_disruption_hash: String.t(),
          latest_disruption_run_id: String.t(),
          resolved: boolean,
          scheduled: boolean,
          ticket_url: String.t(),
          age: integer,
          disruption_timestamps: [Google.Protobuf.Timestamp.t()],
          disruption_history: [InternalApi.Superjerry.DisruptionRecord.t()],
          total_count: non_neg_integer
        }
  defstruct [
    :project_id,
    :test_id,
    :test_name,
    :test_group,
    :test_runner,
    :test_file,
    :test_suite,
    :pass_rate,
    :labels,
    :disruptions_count,
    :latest_disruption_at,
    :first_disruption_at,
    :latest_disruption_hash,
    :latest_disruption_run_id,
    :resolved,
    :scheduled,
    :ticket_url,
    :age,
    :disruption_timestamps,
    :disruption_history,
    :total_count
  ]

  field(:project_id, 1, type: :string)
  field(:test_id, 2, type: :string)
  field(:test_name, 3, type: :string)
  field(:test_group, 4, type: :string)
  field(:test_runner, 5, type: :string)
  field(:test_file, 6, type: :string)
  field(:test_suite, 7, type: :string)
  field(:pass_rate, 8, type: :int32)
  field(:labels, 9, repeated: true, type: :string)
  field(:disruptions_count, 10, type: :int64)
  field(:latest_disruption_at, 11, type: Google.Protobuf.Timestamp)
  field(:first_disruption_at, 12, type: Google.Protobuf.Timestamp)
  field(:latest_disruption_hash, 13, type: :string)
  field(:latest_disruption_run_id, 14, type: :string)
  field(:resolved, 15, type: :bool)
  field(:scheduled, 16, type: :bool)
  field(:ticket_url, 17, type: :string)
  field(:age, 18, type: :int64)
  field(:disruption_timestamps, 19, repeated: true, type: Google.Protobuf.Timestamp)
  field(:disruption_history, 20, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
  field(:total_count, 21, type: :uint64)
end

defmodule InternalApi.Superjerry.DisruptionRecord do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          day: Google.Protobuf.Timestamp.t(),
          count: integer
        }
  defstruct [:day, :count]

  field(:day, 1, type: Google.Protobuf.Timestamp)
  field(:count, 2, type: :int64)
end

defmodule InternalApi.Superjerry.ListFlakyTestsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          pagination: InternalApi.Superjerry.Pagination.t(),
          sort: InternalApi.Superjerry.Sort.t(),
          filters: String.t()
        }
  defstruct [:org_id, :project_id, :pagination, :sort, :filters]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:pagination, 3, type: InternalApi.Superjerry.Pagination)
  field(:sort, 4, type: InternalApi.Superjerry.Sort)
  field(:filters, 5, type: :string)
end

defmodule InternalApi.Superjerry.ListFlakyTestsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          flaky_tests: [InternalApi.Superjerry.Flaky.t()],
          pagination: InternalApi.Superjerry.Pagination.t(),
          total_pages: non_neg_integer,
          total_rows: non_neg_integer
        }
  defstruct [:flaky_tests, :pagination, :total_pages, :total_rows]

  field(:flaky_tests, 1, repeated: true, type: InternalApi.Superjerry.Flaky)
  field(:pagination, 2, type: InternalApi.Superjerry.Pagination)
  field(:total_pages, 3, type: :uint64)
  field(:total_rows, 4, type: :uint64)
end

defmodule InternalApi.Superjerry.ListDisruptionHistoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          filters: String.t()
        }
  defstruct [:org_id, :project_id, :filters]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:filters, 3, type: :string)
end

defmodule InternalApi.Superjerry.ListDisruptionHistoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          disruptions: [InternalApi.Superjerry.DisruptionRecord.t()]
        }
  defstruct [:disruptions]

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
end

defmodule InternalApi.Superjerry.ListFlakyHistoryRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          filters: String.t()
        }
  defstruct [:org_id, :project_id, :filters]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:filters, 3, type: :string)
end

defmodule InternalApi.Superjerry.ListFlakyHistoryResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          disruptions: [InternalApi.Superjerry.DisruptionRecord.t()]
        }
  defstruct [:disruptions]

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
end

defmodule InternalApi.Superjerry.FlakyTestDetailsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          test_id: String.t(),
          filters: String.t()
        }
  defstruct [:org_id, :project_id, :test_id, :filters]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
  field(:filters, 4, type: :string)
end

defmodule InternalApi.Superjerry.FlakyTestDetail do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          id: String.t(),
          name: String.t(),
          group: String.t(),
          runner: String.t(),
          file: String.t(),
          labels: [String.t()],
          available_contexts: [String.t()],
          selected_context: String.t(),
          disruptions_count: [integer],
          pass_rates: [float],
          p95_durations: [float],
          impacts: [float],
          total_counts: [integer],
          contexts: [String.t()],
          hashes: [String.t()],
          disruption_timestamps: [Google.Protobuf.Timestamp.t()],
          disruption_history: [InternalApi.Superjerry.DisruptionRecord.t()]
        }
  defstruct [
    :project_id,
    :id,
    :name,
    :group,
    :runner,
    :file,
    :labels,
    :available_contexts,
    :selected_context,
    :disruptions_count,
    :pass_rates,
    :p95_durations,
    :impacts,
    :total_counts,
    :contexts,
    :hashes,
    :disruption_timestamps,
    :disruption_history
  ]

  field(:project_id, 1, type: :string)
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:group, 4, type: :string)
  field(:runner, 5, type: :string)
  field(:file, 6, type: :string)
  field(:labels, 7, repeated: true, type: :string)
  field(:available_contexts, 8, repeated: true, type: :string)
  field(:selected_context, 9, type: :string)
  field(:disruptions_count, 10, repeated: true, type: :int64)
  field(:pass_rates, 11, repeated: true, type: :double)
  field(:p95_durations, 12, repeated: true, type: :double)
  field(:impacts, 13, repeated: true, type: :double)
  field(:total_counts, 14, repeated: true, type: :int64)
  field(:contexts, 15, repeated: true, type: :string)
  field(:hashes, 16, repeated: true, type: :string)
  field(:disruption_timestamps, 17, repeated: true, type: Google.Protobuf.Timestamp)
  field(:disruption_history, 18, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
end

defmodule InternalApi.Superjerry.FlakyTestDetailsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          detail: InternalApi.Superjerry.FlakyTestDetail.t()
        }
  defstruct [:detail]

  field(:detail, 1, type: InternalApi.Superjerry.FlakyTestDetail)
end

defmodule InternalApi.Superjerry.FlakyTestDisruptionsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          test_id: String.t(),
          filters: String.t(),
          pagination: InternalApi.Superjerry.Pagination.t()
        }
  defstruct [:org_id, :project_id, :test_id, :filters, :pagination]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
  field(:filters, 4, type: :string)
  field(:pagination, 5, type: InternalApi.Superjerry.Pagination)
end

defmodule InternalApi.Superjerry.FlakyTestDisruption do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          context: String.t(),
          hash: String.t(),
          timestamp: Google.Protobuf.Timestamp.t(),
          run_id: String.t(),
          total_count: non_neg_integer
        }
  defstruct [:context, :hash, :timestamp, :run_id, :total_count]

  field(:context, 1, type: :string)
  field(:hash, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
  field(:run_id, 4, type: :string)
  field(:total_count, 5, type: :uint64)
end

defmodule InternalApi.Superjerry.FlakyTestDisruptionsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          disruptions: [InternalApi.Superjerry.FlakyTestDisruption.t()],
          pagination: InternalApi.Superjerry.Pagination.t(),
          total_pages: non_neg_integer,
          total_rows: non_neg_integer
        }
  defstruct [:disruptions, :pagination, :total_pages, :total_rows]

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.FlakyTestDisruption)
  field(:pagination, 2, type: InternalApi.Superjerry.Pagination)
  field(:total_pages, 3, type: :uint64)
  field(:total_rows, 4, type: :uint64)
end

defmodule InternalApi.Superjerry.AddLabelRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          label: String.t(),
          project_id: String.t(),
          test_id: String.t()
        }
  defstruct [:label, :project_id, :test_id]

  field(:label, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
end

defmodule InternalApi.Superjerry.AddLabelResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.DeleteLabelRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          label: String.t(),
          project_id: String.t(),
          test_id: String.t()
        }
  defstruct [:label, :project_id, :test_id]

  field(:label, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
end

defmodule InternalApi.Superjerry.DeleteLabelResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.ResolveFlakyTestRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          project_id: String.t(),
          test_id: String.t()
        }
  defstruct [:user_id, :project_id, :test_id]

  field(:user_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
end

defmodule InternalApi.Superjerry.ResolveFlakyTestResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.UnresolveFlakyTestRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          project_id: String.t(),
          test_id: String.t()
        }
  defstruct [:user_id, :project_id, :test_id]

  field(:user_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
end

defmodule InternalApi.Superjerry.UnresolveFlakyTestResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.SaveTicketUrlRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_id: String.t(),
          project_id: String.t(),
          test_id: String.t(),
          ticket_url: String.t()
        }
  defstruct [:user_id, :project_id, :test_id, :ticket_url]

  field(:user_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_id, 3, type: :string)
  field(:ticket_url, 4, type: :string)
end

defmodule InternalApi.Superjerry.SaveTicketUrlResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.InsertTestResultsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          test_results: [InternalApi.Superjerry.TestResult.t()]
        }
  defstruct [:org_id, :project_id, :test_results]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:test_results, 3, repeated: true, type: InternalApi.Superjerry.TestResult)
end

defmodule InternalApi.Superjerry.InsertTestResultsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.TestResult do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          id: String.t(),
          context: String.t(),
          hash: String.t(),
          run_id: String.t(),
          name: String.t(),
          group: String.t(),
          suite: String.t(),
          file: String.t(),
          framework: String.t(),
          duration: non_neg_integer,
          state: String.t(),
          run_at: Google.Protobuf.Timestamp.t(),
          inserted_at: Google.Protobuf.Timestamp.t()
        }
  defstruct [
    :org_id,
    :project_id,
    :id,
    :context,
    :hash,
    :run_id,
    :name,
    :group,
    :suite,
    :file,
    :framework,
    :duration,
    :state,
    :run_at,
    :inserted_at
  ]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:id, 3, type: :string)
  field(:context, 4, type: :string)
  field(:hash, 5, type: :string)
  field(:run_id, 6, type: :string)
  field(:name, 7, type: :string)
  field(:group, 8, type: :string)
  field(:suite, 9, type: :string)
  field(:file, 10, type: :string)
  field(:framework, 11, type: :string)
  field(:duration, 12, type: :uint64)
  field(:state, 13, type: :string)
  field(:run_at, 14, type: Google.Protobuf.Timestamp)
  field(:inserted_at, 15, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Superjerry.WebhookSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t()
        }
  defstruct [:org_id, :project_id]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.Superjerry.WebhookSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: InternalApi.Superjerry.WebhookSettings.t()
        }
  defstruct [:settings]

  field(:settings, 1, type: InternalApi.Superjerry.WebhookSettings)
end

defmodule InternalApi.Superjerry.CreateWebhookSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          webhook_url: String.t(),
          branches: [String.t()],
          enabled: boolean,
          org_id: String.t(),
          project_id: String.t(),
          greedy: boolean
        }
  defstruct [:webhook_url, :branches, :enabled, :org_id, :project_id, :greedy]

  field(:webhook_url, 1, type: :string)
  field(:branches, 2, repeated: true, type: :string)
  field(:enabled, 3, type: :bool)
  field(:org_id, 4, type: :string)
  field(:project_id, 5, type: :string)
  field(:greedy, 6, type: :bool)
end

defmodule InternalApi.Superjerry.CreateWebhookSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: InternalApi.Superjerry.WebhookSettings.t()
        }
  defstruct [:settings]

  field(:settings, 1, type: InternalApi.Superjerry.WebhookSettings)
end

defmodule InternalApi.Superjerry.WebhookSettings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          webhook_url: String.t(),
          branches: [String.t()],
          enabled: boolean,
          org_id: String.t(),
          project_id: String.t(),
          greedy: boolean
        }
  defstruct [:id, :webhook_url, :branches, :enabled, :org_id, :project_id, :greedy]

  field(:id, 1, type: :string)
  field(:webhook_url, 2, type: :string)
  field(:branches, 3, repeated: true, type: :string)
  field(:enabled, 4, type: :bool)
  field(:org_id, 5, type: :string)
  field(:project_id, 6, type: :string)
  field(:greedy, 7, type: :bool)
end

defmodule InternalApi.Superjerry.UpdateWebhookSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t(),
          webhook_url: String.t(),
          branches: [String.t()],
          enabled: boolean,
          greedy: boolean
        }
  defstruct [:org_id, :project_id, :webhook_url, :branches, :enabled, :greedy]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
  field(:webhook_url, 3, type: :string)
  field(:branches, 4, repeated: true, type: :string)
  field(:enabled, 5, type: :bool)
  field(:greedy, 6, type: :bool)
end

defmodule InternalApi.Superjerry.UpdateWebhookSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.DeleteWebhookSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          org_id: String.t(),
          project_id: String.t()
        }
  defstruct [:org_id, :project_id]

  field(:org_id, 1, type: :string)
  field(:project_id, 2, type: :string)
end

defmodule InternalApi.Superjerry.DeleteWebhookSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  defstruct []
end

defmodule InternalApi.Superjerry.Superjerry.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Superjerry.Superjerry"

  rpc(
    :ListFlakyTests,
    InternalApi.Superjerry.ListFlakyTestsRequest,
    InternalApi.Superjerry.ListFlakyTestsResponse
  )

  rpc(
    :ListDisruptionHistory,
    InternalApi.Superjerry.ListDisruptionHistoryRequest,
    InternalApi.Superjerry.ListDisruptionHistoryResponse
  )

  rpc(
    :ListFlakyHistory,
    InternalApi.Superjerry.ListFlakyHistoryRequest,
    InternalApi.Superjerry.ListFlakyHistoryResponse
  )

  rpc(
    :FlakyTestDetails,
    InternalApi.Superjerry.FlakyTestDetailsRequest,
    InternalApi.Superjerry.FlakyTestDetailsResponse
  )

  rpc(
    :FlakyTestDisruptions,
    InternalApi.Superjerry.FlakyTestDisruptionsRequest,
    InternalApi.Superjerry.FlakyTestDisruptionsResponse
  )

  rpc(:AddLabel, InternalApi.Superjerry.AddLabelRequest, InternalApi.Superjerry.AddLabelResponse)

  rpc(
    :DeleteLabel,
    InternalApi.Superjerry.DeleteLabelRequest,
    InternalApi.Superjerry.DeleteLabelResponse
  )

  rpc(
    :ResolveFlakyTest,
    InternalApi.Superjerry.ResolveFlakyTestRequest,
    InternalApi.Superjerry.ResolveFlakyTestResponse
  )

  rpc(
    :UnresolveFlakyTest,
    InternalApi.Superjerry.UnresolveFlakyTestRequest,
    InternalApi.Superjerry.UnresolveFlakyTestResponse
  )

  rpc(
    :SaveTicketUrl,
    InternalApi.Superjerry.SaveTicketUrlRequest,
    InternalApi.Superjerry.SaveTicketUrlResponse
  )

  rpc(
    :InsertTestResults,
    InternalApi.Superjerry.InsertTestResultsRequest,
    InternalApi.Superjerry.InsertTestResultsResponse
  )

  rpc(
    :WebhookSettings,
    InternalApi.Superjerry.WebhookSettingsRequest,
    InternalApi.Superjerry.WebhookSettingsResponse
  )

  rpc(
    :CreateWebhookSettings,
    InternalApi.Superjerry.CreateWebhookSettingsRequest,
    InternalApi.Superjerry.CreateWebhookSettingsResponse
  )

  rpc(
    :UpdateWebhookSettings,
    InternalApi.Superjerry.UpdateWebhookSettingsRequest,
    InternalApi.Superjerry.UpdateWebhookSettingsResponse
  )

  rpc(
    :DeleteWebhookSettings,
    InternalApi.Superjerry.DeleteWebhookSettingsRequest,
    InternalApi.Superjerry.DeleteWebhookSettingsResponse
  )
end

defmodule InternalApi.Superjerry.Superjerry.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Superjerry.Superjerry.Service
end
