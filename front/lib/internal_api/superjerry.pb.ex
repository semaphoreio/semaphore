defmodule InternalApi.Superjerry.Sort.Direction do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:ASC, 0)
  field(:DESC, 1)
end

defmodule InternalApi.Superjerry.Pagination do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:page, 1, type: :uint32)
  field(:page_size, 2, type: :uint32, json_name: "pageSize")
end

defmodule InternalApi.Superjerry.Sort do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:dir, 1, type: InternalApi.Superjerry.Sort.Direction, enum: true)
  field(:name, 2, type: :string)
end

defmodule InternalApi.Superjerry.Flaky do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:test_id, 2, type: :string, json_name: "testId")
  field(:test_name, 3, type: :string, json_name: "testName")
  field(:test_group, 4, type: :string, json_name: "testGroup")
  field(:test_runner, 5, type: :string, json_name: "testRunner")
  field(:test_file, 6, type: :string, json_name: "testFile")
  field(:test_suite, 7, type: :string, json_name: "testSuite")
  field(:pass_rate, 8, type: :int32, json_name: "passRate")
  field(:labels, 9, repeated: true, type: :string)
  field(:disruptions_count, 10, type: :int64, json_name: "disruptionsCount")

  field(:latest_disruption_at, 11,
    type: Google.Protobuf.Timestamp,
    json_name: "latestDisruptionAt"
  )

  field(:first_disruption_at, 12, type: Google.Protobuf.Timestamp, json_name: "firstDisruptionAt")
  field(:latest_disruption_hash, 13, type: :string, json_name: "latestDisruptionHash")
  field(:latest_disruption_run_id, 14, type: :string, json_name: "latestDisruptionRunId")
  field(:resolved, 15, type: :bool)
  field(:scheduled, 16, type: :bool)
  field(:ticket_url, 17, type: :string, json_name: "ticketUrl")
  field(:age, 18, type: :int64)

  field(:disruption_timestamps, 19,
    repeated: true,
    type: Google.Protobuf.Timestamp,
    json_name: "disruptionTimestamps"
  )

  field(:disruption_history, 20,
    repeated: true,
    type: InternalApi.Superjerry.DisruptionRecord,
    json_name: "disruptionHistory"
  )

  field(:total_count, 21, type: :uint64, json_name: "totalCount")
end

defmodule InternalApi.Superjerry.DisruptionRecord do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:day, 1, type: Google.Protobuf.Timestamp)
  field(:count, 2, type: :int64)
end

defmodule InternalApi.Superjerry.ListFlakyTestsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:pagination, 3, type: InternalApi.Superjerry.Pagination)
  field(:sort, 4, type: InternalApi.Superjerry.Sort)
  field(:filters, 5, type: :string)
end

defmodule InternalApi.Superjerry.ListFlakyTestsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:flaky_tests, 1,
    repeated: true,
    type: InternalApi.Superjerry.Flaky,
    json_name: "flakyTests"
  )

  field(:pagination, 2, type: InternalApi.Superjerry.Pagination)
  field(:total_pages, 3, type: :uint64, json_name: "totalPages")
  field(:total_rows, 4, type: :uint64, json_name: "totalRows")
end

defmodule InternalApi.Superjerry.ListDisruptionHistoryRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:filters, 3, type: :string)
end

defmodule InternalApi.Superjerry.ListDisruptionHistoryResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
end

defmodule InternalApi.Superjerry.ListFlakyHistoryRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:filters, 3, type: :string)
end

defmodule InternalApi.Superjerry.ListFlakyHistoryResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.DisruptionRecord)
end

defmodule InternalApi.Superjerry.FlakyTestDetailsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
  field(:filters, 4, type: :string)
end

defmodule InternalApi.Superjerry.FlakyTestDetail do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:id, 2, type: :string)
  field(:name, 3, type: :string)
  field(:group, 4, type: :string)
  field(:runner, 5, type: :string)
  field(:file, 6, type: :string)
  field(:labels, 7, repeated: true, type: :string)
  field(:available_contexts, 8, repeated: true, type: :string, json_name: "availableContexts")
  field(:selected_context, 9, type: :string, json_name: "selectedContext")
  field(:disruptions_count, 10, repeated: true, type: :int64, json_name: "disruptionsCount")
  field(:pass_rates, 11, repeated: true, type: :double, json_name: "passRates")
  field(:p95_durations, 12, repeated: true, type: :double, json_name: "p95Durations")
  field(:impacts, 13, repeated: true, type: :double)
  field(:total_counts, 14, repeated: true, type: :int64, json_name: "totalCounts")
  field(:contexts, 15, repeated: true, type: :string)
  field(:hashes, 16, repeated: true, type: :string)

  field(:disruption_timestamps, 17,
    repeated: true,
    type: Google.Protobuf.Timestamp,
    json_name: "disruptionTimestamps"
  )

  field(:disruption_history, 18,
    repeated: true,
    type: InternalApi.Superjerry.DisruptionRecord,
    json_name: "disruptionHistory"
  )
end

defmodule InternalApi.Superjerry.FlakyTestDetailsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:detail, 1, type: InternalApi.Superjerry.FlakyTestDetail)
end

defmodule InternalApi.Superjerry.FlakyTestDisruptionsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
  field(:filters, 4, type: :string)
  field(:pagination, 5, type: InternalApi.Superjerry.Pagination)
end

defmodule InternalApi.Superjerry.FlakyTestDisruption do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:context, 1, type: :string)
  field(:hash, 2, type: :string)
  field(:timestamp, 3, type: Google.Protobuf.Timestamp)
  field(:run_id, 4, type: :string, json_name: "runId")
  field(:total_count, 5, type: :uint64, json_name: "totalCount")
end

defmodule InternalApi.Superjerry.FlakyTestDisruptionsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:disruptions, 1, repeated: true, type: InternalApi.Superjerry.FlakyTestDisruption)
  field(:pagination, 2, type: InternalApi.Superjerry.Pagination)
  field(:total_pages, 3, type: :uint64, json_name: "totalPages")
  field(:total_rows, 4, type: :uint64, json_name: "totalRows")
end

defmodule InternalApi.Superjerry.AddLabelRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:label, 1, type: :string)
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
end

defmodule InternalApi.Superjerry.AddLabelResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.DeleteLabelRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:label, 1, type: :string)
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
end

defmodule InternalApi.Superjerry.DeleteLabelResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.ResolveFlakyTestRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
end

defmodule InternalApi.Superjerry.ResolveFlakyTestResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.UnresolveFlakyTestRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
end

defmodule InternalApi.Superjerry.UnresolveFlakyTestResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.SaveTicketUrlRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:user_id, 1, type: :string, json_name: "userId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:test_id, 3, type: :string, json_name: "testId")
  field(:ticket_url, 4, type: :string, json_name: "ticketUrl")
end

defmodule InternalApi.Superjerry.SaveTicketUrlResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.InsertTestResultsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")

  field(:test_results, 3,
    repeated: true,
    type: InternalApi.Superjerry.TestResult,
    json_name: "testResults"
  )
end

defmodule InternalApi.Superjerry.InsertTestResultsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.TestResult do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:id, 3, type: :string)
  field(:context, 4, type: :string)
  field(:hash, 5, type: :string)
  field(:run_id, 6, type: :string, json_name: "runId")
  field(:name, 7, type: :string)
  field(:group, 8, type: :string)
  field(:suite, 9, type: :string)
  field(:file, 10, type: :string)
  field(:framework, 11, type: :string)
  field(:duration, 12, type: :uint64)
  field(:state, 13, type: :string)
  field(:run_at, 14, type: Google.Protobuf.Timestamp, json_name: "runAt")
  field(:inserted_at, 15, type: Google.Protobuf.Timestamp, json_name: "insertedAt")
end

defmodule InternalApi.Superjerry.WebhookSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.Superjerry.WebhookSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:settings, 1, type: InternalApi.Superjerry.WebhookSettings)
end

defmodule InternalApi.Superjerry.CreateWebhookSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:webhook_url, 1, type: :string, json_name: "webhookUrl")
  field(:branches, 2, repeated: true, type: :string)
  field(:enabled, 3, type: :bool)
  field(:org_id, 4, type: :string, json_name: "orgId")
  field(:project_id, 5, type: :string, json_name: "projectId")
  field(:greedy, 6, type: :bool)
end

defmodule InternalApi.Superjerry.CreateWebhookSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:settings, 1, type: InternalApi.Superjerry.WebhookSettings)
end

defmodule InternalApi.Superjerry.WebhookSettings do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:webhook_url, 2, type: :string, json_name: "webhookUrl")
  field(:branches, 3, repeated: true, type: :string)
  field(:enabled, 4, type: :bool)
  field(:org_id, 5, type: :string, json_name: "orgId")
  field(:project_id, 6, type: :string, json_name: "projectId")
  field(:greedy, 7, type: :bool)
end

defmodule InternalApi.Superjerry.UpdateWebhookSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:webhook_url, 3, type: :string, json_name: "webhookUrl")
  field(:branches, 4, repeated: true, type: :string)
  field(:enabled, 5, type: :bool)
  field(:greedy, 6, type: :bool)
end

defmodule InternalApi.Superjerry.UpdateWebhookSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.DeleteWebhookSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:org_id, 1, type: :string, json_name: "orgId")
  field(:project_id, 2, type: :string, json_name: "projectId")
end

defmodule InternalApi.Superjerry.DeleteWebhookSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Superjerry.Superjerry.Service do
  @moduledoc false

  use GRPC.Service, name: "InternalApi.Superjerry.Superjerry", protoc_gen_elixir_version: "0.13.0"

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
