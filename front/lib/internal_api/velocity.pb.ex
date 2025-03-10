defmodule InternalApi.Velocity.Metric do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:METRIC_UNSPECIFIED, 0)
  field(:METRIC_PERFORMANCE, 1)
  field(:METRIC_FREQUENCY, 2)
  field(:METRIC_RELIABILITY, 3)
end

defmodule InternalApi.Velocity.MetricAggregation do
  @moduledoc false

  use Protobuf, enum: true, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:RANGE, 0)
  field(:DAILY, 1)
end

defmodule InternalApi.Velocity.InitializeFlakyTestsFiltersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
end

defmodule InternalApi.Velocity.InitializeFlakyTestsFiltersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:filters, 1, repeated: true, type: InternalApi.Velocity.FlakyTestsFilter)
end

defmodule InternalApi.Velocity.ListFlakyTestsFiltersRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
end

defmodule InternalApi.Velocity.ListFlakyTestsFiltersResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:filters, 1, repeated: true, type: InternalApi.Velocity.FlakyTestsFilter)
end

defmodule InternalApi.Velocity.CreateFlakyTestsFilterRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:name, 3, type: :string)
  field(:value, 4, type: :string)
end

defmodule InternalApi.Velocity.CreateFlakyTestsFilterResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:filter, 1, type: InternalApi.Velocity.FlakyTestsFilter)
end

defmodule InternalApi.Velocity.FlakyTestsFilter do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:organization_id, 3, type: :string, json_name: "organizationId")
  field(:inserted_at, 4, type: Google.Protobuf.Timestamp, json_name: "insertedAt")
  field(:updated_at, 5, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:name, 6, type: :string)
  field(:value, 7, type: :string)
end

defmodule InternalApi.Velocity.RemoveFlakyTestsFilterRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Velocity.RemoveFlakyTestsFilterResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.UpdateFlakyTestsFilterRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:value, 3, type: :string)
end

defmodule InternalApi.Velocity.UpdateFlakyTestsFilterResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:filter, 1, type: InternalApi.Velocity.FlakyTestsFilter)
end

defmodule InternalApi.Velocity.OrganizationHealthRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_ids, 1, repeated: true, type: :string, json_name: "projectIds")
  field(:org_id, 2, type: :string, json_name: "orgId")
  field(:from_date, 3, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 4, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.OrganizationHealthResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:health_metrics, 1,
    repeated: true,
    type: InternalApi.Velocity.ProjectHealthMetrics,
    json_name: "healthMetrics"
  )
end

defmodule InternalApi.Velocity.ProjectHealthMetrics do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:project_name, 2, type: :string, json_name: "projectName")
  field(:mean_time_to_recovery_seconds, 3, type: :int32, json_name: "meanTimeToRecoverySeconds")

  field(:last_successful_run_at, 4,
    type: Google.Protobuf.Timestamp,
    json_name: "lastSuccessfulRunAt"
  )

  field(:default_branch, 5, type: InternalApi.Velocity.Stats, json_name: "defaultBranch")
  field(:all_branches, 6, type: InternalApi.Velocity.Stats, json_name: "allBranches")
  field(:parallelism, 7, type: :int32)
  field(:deployments, 8, type: :int32)
end

defmodule InternalApi.Velocity.Stats do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:all_count, 1, type: :int32, json_name: "allCount")
  field(:passed_count, 2, type: :int32, json_name: "passedCount")
  field(:failed_count, 3, type: :int32, json_name: "failedCount")
  field(:avg_seconds, 4, type: :int32, json_name: "avgSeconds")
  field(:avg_seconds_successful, 5, type: :int32, json_name: "avgSecondsSuccessful")
  field(:queue_time_seconds, 6, type: :int32, json_name: "queueTimeSeconds")
  field(:queue_time_seconds_successful, 7, type: :int32, json_name: "queueTimeSecondsSuccessful")
end

defmodule InternalApi.Velocity.DescribeDashboardItemRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Velocity.DescribeDashboardItemResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:item, 1, type: InternalApi.Velocity.DashboardItem)
end

defmodule InternalApi.Velocity.DeleteDashboardItemRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Velocity.DeleteDashboardItemResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.DeleteMetricsDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Velocity.DeleteMetricsDashboardResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.ListMetricsDashboardsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
end

defmodule InternalApi.Velocity.ListMetricsDashboardsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:dashboards, 1, repeated: true, type: InternalApi.Velocity.MetricsDashboard)
end

defmodule InternalApi.Velocity.DescribeMetricsDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
end

defmodule InternalApi.Velocity.DescribeMetricsDashboardResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:dashboard, 1, type: InternalApi.Velocity.MetricsDashboard)
end

defmodule InternalApi.Velocity.MetricsDashboard do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:project_id, 3, type: :string, json_name: "projectId")
  field(:organization_id, 4, type: :string, json_name: "organizationId")
  field(:inserted_at, 5, type: Google.Protobuf.Timestamp, json_name: "insertedAt")
  field(:updated_at, 6, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:items, 7, repeated: true, type: InternalApi.Velocity.DashboardItem)
end

defmodule InternalApi.Velocity.DashboardItem do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
  field(:metrics_dashboard_id, 3, type: :string, json_name: "metricsDashboardId")
  field(:branch_name, 4, type: :string, json_name: "branchName")
  field(:pipeline_file_name, 5, type: :string, json_name: "pipelineFileName")
  field(:inserted_at, 6, type: Google.Protobuf.Timestamp, json_name: "insertedAt")
  field(:updated_at, 7, type: Google.Protobuf.Timestamp, json_name: "updatedAt")
  field(:settings, 8, type: InternalApi.Velocity.DashboardItemSettings)
  field(:notes, 9, type: :string)
end

defmodule InternalApi.Velocity.DashboardItemSettings do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:metric, 1, type: InternalApi.Velocity.Metric, enum: true)
  field(:goal, 2, type: :string)
end

defmodule InternalApi.Velocity.CreateMetricsDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:organization_id, 3, type: :string, json_name: "organizationId")
end

defmodule InternalApi.Velocity.CreateMetricsDashboardResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:dashboard, 1, type: InternalApi.Velocity.MetricsDashboard)
end

defmodule InternalApi.Velocity.UpdateMetricsDashboardRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule InternalApi.Velocity.UpdateMetricsDashboardResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.CreateDashboardItemRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:name, 1, type: :string)
  field(:metrics_dashboard_id, 2, type: :string, json_name: "metricsDashboardId")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:pipeline_file_name, 4, type: :string, json_name: "pipelineFileName")
  field(:settings, 5, type: InternalApi.Velocity.DashboardItemSettings)
  field(:notes, 6, type: :string)
end

defmodule InternalApi.Velocity.CreateDashboardItemResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:item, 1, type: InternalApi.Velocity.DashboardItem)
end

defmodule InternalApi.Velocity.UpdateDashboardItemRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:name, 2, type: :string)
end

defmodule InternalApi.Velocity.UpdateDashboardItemResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.ChangeDashboardItemNotesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:id, 1, type: :string)
  field(:notes, 2, type: :string)
end

defmodule InternalApi.Velocity.ChangeDashboardItemNotesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"
end

defmodule InternalApi.Velocity.ListPipelinePerformanceMetricsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:pipeline_file_name, 2, type: :string, json_name: "pipelineFileName")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true)
  field(:from_date, 5, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 6, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.ListPipelinePerformanceMetricsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:all_metrics, 1,
    repeated: true,
    type: InternalApi.Velocity.PerformanceMetric,
    json_name: "allMetrics"
  )

  field(:passed_metrics, 2,
    repeated: true,
    type: InternalApi.Velocity.PerformanceMetric,
    json_name: "passedMetrics"
  )

  field(:failed_metrics, 3,
    repeated: true,
    type: InternalApi.Velocity.PerformanceMetric,
    json_name: "failedMetrics"
  )
end

defmodule InternalApi.Velocity.PerformanceMetric do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:from_date, 1, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 2, type: Google.Protobuf.Timestamp, json_name: "toDate")
  field(:count, 3, type: :int32)
  field(:mean_seconds, 4, type: :int32, json_name: "meanSeconds")
  field(:median_seconds, 5, type: :int32, json_name: "medianSeconds")
  field(:min_seconds, 6, type: :int32, json_name: "minSeconds")
  field(:max_seconds, 7, type: :int32, json_name: "maxSeconds")
  field(:std_dev_seconds, 8, type: :int32, json_name: "stdDevSeconds")
  field(:p95_seconds, 9, type: :int32, json_name: "p95Seconds")
end

defmodule InternalApi.Velocity.ListPipelineReliabilityMetricsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:pipeline_file_name, 2, type: :string, json_name: "pipelineFileName")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true)
  field(:from_date, 5, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 6, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.ListPipelineReliabilityMetricsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:metrics, 1, repeated: true, type: InternalApi.Velocity.ReliabilityMetric)
end

defmodule InternalApi.Velocity.ReliabilityMetric do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:from_date, 1, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 2, type: Google.Protobuf.Timestamp, json_name: "toDate")
  field(:all_count, 3, type: :int32, json_name: "allCount")
  field(:passed_count, 4, type: :int32, json_name: "passedCount")
  field(:failed_count, 5, type: :int32, json_name: "failedCount")
end

defmodule InternalApi.Velocity.ListPipelineFrequencyMetricsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:pipeline_file_name, 2, type: :string, json_name: "pipelineFileName")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true)
  field(:from_date, 5, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 6, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.ListPipelineFrequencyMetricsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:metrics, 1, repeated: true, type: InternalApi.Velocity.FrequencyMetric)
end

defmodule InternalApi.Velocity.FrequencyMetric do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:from_date, 1, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 2, type: Google.Protobuf.Timestamp, json_name: "toDate")
  field(:all_count, 3, type: :int32, json_name: "allCount")
end

defmodule InternalApi.Velocity.DescribeProjectPerformanceRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:pipeline_file_name, 2, type: :string, json_name: "pipelineFileName")
  field(:branch_name, 3, type: :string, json_name: "branchName")
  field(:from_date, 4, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 5, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.DescribeProjectPerformanceResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:mean_time_to_recovery_seconds, 1, type: :int32, json_name: "meanTimeToRecoverySeconds")

  field(:last_successful_run_at, 2,
    type: Google.Protobuf.Timestamp,
    json_name: "lastSuccessfulRunAt"
  )

  field(:from_date, 3, type: Google.Protobuf.Timestamp, json_name: "fromDate")
  field(:to_date, 4, type: Google.Protobuf.Timestamp, json_name: "toDate")
end

defmodule InternalApi.Velocity.DescribeProjectSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
end

defmodule InternalApi.Velocity.DescribeProjectSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:settings, 1, type: InternalApi.Velocity.Settings)
end

defmodule InternalApi.Velocity.UpdateProjectSettingsRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:settings, 2, type: InternalApi.Velocity.Settings)
end

defmodule InternalApi.Velocity.UpdateProjectSettingsResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:settings, 1, type: InternalApi.Velocity.Settings)
end

defmodule InternalApi.Velocity.Settings do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:cd_branch_name, 1, type: :string, json_name: "cdBranchName")
  field(:cd_pipeline_file_name, 2, type: :string, json_name: "cdPipelineFileName")
  field(:ci_branch_name, 3, type: :string, json_name: "ciBranchName")
  field(:ci_pipeline_file_name, 4, type: :string, json_name: "ciPipelineFileName")
end

defmodule InternalApi.Velocity.ListPipelineSummariesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:pipeline_ids, 1, repeated: true, type: :string, json_name: "pipelineIds")
end

defmodule InternalApi.Velocity.ListPipelineSummariesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:pipeline_summaries, 1,
    repeated: true,
    type: InternalApi.Velocity.PipelineSummary,
    json_name: "pipelineSummaries"
  )
end

defmodule InternalApi.Velocity.ListJobSummariesRequest do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_ids, 1, repeated: true, type: :string, json_name: "jobIds")
end

defmodule InternalApi.Velocity.ListJobSummariesResponse do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_summaries, 1,
    repeated: true,
    type: InternalApi.Velocity.JobSummary,
    json_name: "jobSummaries"
  )
end

defmodule InternalApi.Velocity.PipelineSummary do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:summary, 3, type: InternalApi.Velocity.Summary)
end

defmodule InternalApi.Velocity.JobSummary do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:pipeline_id, 2, type: :string, json_name: "pipelineId")
  field(:summary, 4, type: InternalApi.Velocity.Summary)
end

defmodule InternalApi.Velocity.Summary do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:total, 1, type: :int32)
  field(:passed, 2, type: :int32)
  field(:skipped, 3, type: :int32)
  field(:error, 4, type: :int32)
  field(:failed, 5, type: :int32)
  field(:disabled, 6, type: :int32)
  field(:duration, 7, type: :int64)
end

defmodule InternalApi.Velocity.PipelineSummaryAvailableEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:pipeline_id, 1, type: :string, json_name: "pipelineId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Velocity.JobSummaryAvailableEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:job_id, 1, type: :string, json_name: "jobId")
  field(:timestamp, 2, type: Google.Protobuf.Timestamp)
end

defmodule InternalApi.Velocity.CollectPipelineMetricsEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:project_id, 1, type: :string, json_name: "projectId")
  field(:organization_id, 2, type: :string, json_name: "organizationId")
  field(:pipeline_file_name, 3, type: :string, json_name: "pipelineFileName")
  field(:branch_name, 4, type: :string, json_name: "branchName")
  field(:metric_day, 5, type: Google.Protobuf.Timestamp, json_name: "metricDay")
  field(:timestamp, 6, type: Google.Protobuf.Timestamp)
  field(:project_name, 7, type: :string, json_name: "projectName")
end

defmodule InternalApi.Velocity.CollectSuperjerryJobReportEvent do
  @moduledoc false

  use Protobuf, syntax: :proto3, protoc_gen_elixir_version: "0.13.0"

  field(:organization_id, 1, type: :string, json_name: "organizationId")
  field(:project_id, 2, type: :string, json_name: "projectId")
  field(:pipeline_id, 3, type: :string, json_name: "pipelineId")
  field(:job_id, 4, type: :string, json_name: "jobId")
end

defmodule InternalApi.Velocity.PipelineMetricsService.Service do
  @moduledoc false

  use GRPC.Service,
    name: "InternalApi.Velocity.PipelineMetricsService",
    protoc_gen_elixir_version: "0.13.0"

  rpc(
    :ListPipelineSummaries,
    InternalApi.Velocity.ListPipelineSummariesRequest,
    InternalApi.Velocity.ListPipelineSummariesResponse
  )

  rpc(
    :ListJobSummaries,
    InternalApi.Velocity.ListJobSummariesRequest,
    InternalApi.Velocity.ListJobSummariesResponse
  )

  rpc(
    :ListPipelinePerformanceMetrics,
    InternalApi.Velocity.ListPipelinePerformanceMetricsRequest,
    InternalApi.Velocity.ListPipelinePerformanceMetricsResponse
  )

  rpc(
    :ListPipelineReliabilityMetrics,
    InternalApi.Velocity.ListPipelineReliabilityMetricsRequest,
    InternalApi.Velocity.ListPipelineReliabilityMetricsResponse
  )

  rpc(
    :ListPipelineFrequencyMetrics,
    InternalApi.Velocity.ListPipelineFrequencyMetricsRequest,
    InternalApi.Velocity.ListPipelineFrequencyMetricsResponse
  )

  rpc(
    :DescribeProjectPerformance,
    InternalApi.Velocity.DescribeProjectPerformanceRequest,
    InternalApi.Velocity.DescribeProjectPerformanceResponse
  )

  rpc(
    :DescribeProjectSettings,
    InternalApi.Velocity.DescribeProjectSettingsRequest,
    InternalApi.Velocity.DescribeProjectSettingsResponse
  )

  rpc(
    :UpdateProjectSettings,
    InternalApi.Velocity.UpdateProjectSettingsRequest,
    InternalApi.Velocity.UpdateProjectSettingsResponse
  )

  rpc(
    :DescribeMetricsDashboard,
    InternalApi.Velocity.DescribeMetricsDashboardRequest,
    InternalApi.Velocity.DescribeMetricsDashboardResponse
  )

  rpc(
    :ListMetricsDashboards,
    InternalApi.Velocity.ListMetricsDashboardsRequest,
    InternalApi.Velocity.ListMetricsDashboardsResponse
  )

  rpc(
    :CreateMetricsDashboard,
    InternalApi.Velocity.CreateMetricsDashboardRequest,
    InternalApi.Velocity.CreateMetricsDashboardResponse
  )

  rpc(
    :UpdateMetricsDashboard,
    InternalApi.Velocity.UpdateMetricsDashboardRequest,
    InternalApi.Velocity.UpdateMetricsDashboardResponse
  )

  rpc(
    :DeleteMetricsDashboard,
    InternalApi.Velocity.DeleteMetricsDashboardRequest,
    InternalApi.Velocity.DeleteMetricsDashboardResponse
  )

  rpc(
    :CreateDashboardItem,
    InternalApi.Velocity.CreateDashboardItemRequest,
    InternalApi.Velocity.CreateDashboardItemResponse
  )

  rpc(
    :UpdateDashboardItem,
    InternalApi.Velocity.UpdateDashboardItemRequest,
    InternalApi.Velocity.UpdateDashboardItemResponse
  )

  rpc(
    :DeleteDashboardItem,
    InternalApi.Velocity.DeleteDashboardItemRequest,
    InternalApi.Velocity.DeleteDashboardItemResponse
  )

  rpc(
    :DescribeDashboardItem,
    InternalApi.Velocity.DescribeDashboardItemRequest,
    InternalApi.Velocity.DescribeDashboardItemResponse
  )

  rpc(
    :ChangeDashboardItemNotes,
    InternalApi.Velocity.ChangeDashboardItemNotesRequest,
    InternalApi.Velocity.ChangeDashboardItemNotesResponse
  )

  rpc(
    :FetchOrganizationHealth,
    InternalApi.Velocity.OrganizationHealthRequest,
    InternalApi.Velocity.OrganizationHealthResponse
  )

  rpc(
    :ListFlakyTestsFilters,
    InternalApi.Velocity.ListFlakyTestsFiltersRequest,
    InternalApi.Velocity.ListFlakyTestsFiltersResponse
  )

  rpc(
    :CreateFlakyTestsFilter,
    InternalApi.Velocity.CreateFlakyTestsFilterRequest,
    InternalApi.Velocity.CreateFlakyTestsFilterResponse
  )

  rpc(
    :RemoveFlakyTestsFilter,
    InternalApi.Velocity.RemoveFlakyTestsFilterRequest,
    InternalApi.Velocity.RemoveFlakyTestsFilterResponse
  )

  rpc(
    :UpdateFlakyTestsFilter,
    InternalApi.Velocity.UpdateFlakyTestsFilterRequest,
    InternalApi.Velocity.UpdateFlakyTestsFilterResponse
  )

  rpc(
    :InitializeFlakyTestsFilters,
    InternalApi.Velocity.InitializeFlakyTestsFiltersRequest,
    InternalApi.Velocity.InitializeFlakyTestsFiltersResponse
  )
end

defmodule InternalApi.Velocity.PipelineMetricsService.Stub do
  @moduledoc false

  use GRPC.Stub, service: InternalApi.Velocity.PipelineMetricsService.Service
end
