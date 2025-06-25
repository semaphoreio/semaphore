defmodule InternalApi.Velocity.Metric do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :METRIC_UNSPECIFIED
          | :METRIC_PERFORMANCE
          | :METRIC_FREQUENCY
          | :METRIC_RELIABILITY

  field :METRIC_UNSPECIFIED, 0

  field :METRIC_PERFORMANCE, 1

  field :METRIC_FREQUENCY, 2

  field :METRIC_RELIABILITY, 3
end

defmodule InternalApi.Velocity.MetricAggregation do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :RANGE | :DAILY

  field :RANGE, 0

  field :DAILY, 1
end

defmodule InternalApi.Velocity.InitializeFlakyTestsFiltersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          organization_id: String.t()
        }

  defstruct [:project_id, :organization_id]

  field :project_id, 1, type: :string
  field :organization_id, 2, type: :string
end

defmodule InternalApi.Velocity.InitializeFlakyTestsFiltersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          filters: [InternalApi.Velocity.FlakyTestsFilter.t()]
        }

  defstruct [:filters]

  field :filters, 1, repeated: true, type: InternalApi.Velocity.FlakyTestsFilter
end

defmodule InternalApi.Velocity.ListFlakyTestsFiltersRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          organization_id: String.t()
        }

  defstruct [:project_id, :organization_id]

  field :project_id, 1, type: :string
  field :organization_id, 2, type: :string
end

defmodule InternalApi.Velocity.ListFlakyTestsFiltersResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          filters: [InternalApi.Velocity.FlakyTestsFilter.t()]
        }

  defstruct [:filters]

  field :filters, 1, repeated: true, type: InternalApi.Velocity.FlakyTestsFilter
end

defmodule InternalApi.Velocity.CreateFlakyTestsFilterRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          organization_id: String.t(),
          name: String.t(),
          value: String.t()
        }

  defstruct [:project_id, :organization_id, :name, :value]

  field :project_id, 1, type: :string
  field :organization_id, 2, type: :string
  field :name, 3, type: :string
  field :value, 4, type: :string
end

defmodule InternalApi.Velocity.CreateFlakyTestsFilterResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          filter: InternalApi.Velocity.FlakyTestsFilter.t() | nil
        }

  defstruct [:filter]

  field :filter, 1, type: InternalApi.Velocity.FlakyTestsFilter
end

defmodule InternalApi.Velocity.FlakyTestsFilter do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          project_id: String.t(),
          organization_id: String.t(),
          inserted_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil,
          name: String.t(),
          value: String.t()
        }

  defstruct [:id, :project_id, :organization_id, :inserted_at, :updated_at, :name, :value]

  field :id, 1, type: :string
  field :project_id, 2, type: :string
  field :organization_id, 3, type: :string
  field :inserted_at, 4, type: Google.Protobuf.Timestamp
  field :updated_at, 5, type: Google.Protobuf.Timestamp
  field :name, 6, type: :string
  field :value, 7, type: :string
end

defmodule InternalApi.Velocity.RemoveFlakyTestsFilterRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field :id, 1, type: :string
end

defmodule InternalApi.Velocity.RemoveFlakyTestsFilterResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.UpdateFlakyTestsFilterRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          value: String.t()
        }

  defstruct [:id, :name, :value]

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :value, 3, type: :string
end

defmodule InternalApi.Velocity.UpdateFlakyTestsFilterResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          filter: InternalApi.Velocity.FlakyTestsFilter.t() | nil
        }

  defstruct [:filter]

  field :filter, 1, type: InternalApi.Velocity.FlakyTestsFilter
end

defmodule InternalApi.Velocity.OrganizationHealthRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_ids: [String.t()],
          org_id: String.t(),
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:project_ids, :org_id, :from_date, :to_date]

  field :project_ids, 1, repeated: true, type: :string
  field :org_id, 2, type: :string
  field :from_date, 3, type: Google.Protobuf.Timestamp
  field :to_date, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.OrganizationHealthResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          health_metrics: [InternalApi.Velocity.ProjectHealthMetrics.t()]
        }

  defstruct [:health_metrics]

  field :health_metrics, 1, repeated: true, type: InternalApi.Velocity.ProjectHealthMetrics
end

defmodule InternalApi.Velocity.ProjectHealthMetrics do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          project_name: String.t(),
          mean_time_to_recovery_seconds: integer,
          last_successful_run_at: Google.Protobuf.Timestamp.t() | nil,
          default_branch: InternalApi.Velocity.Stats.t() | nil,
          all_branches: InternalApi.Velocity.Stats.t() | nil,
          parallelism: integer,
          deployments: integer
        }

  defstruct [
    :project_id,
    :project_name,
    :mean_time_to_recovery_seconds,
    :last_successful_run_at,
    :default_branch,
    :all_branches,
    :parallelism,
    :deployments
  ]

  field :project_id, 1, type: :string
  field :project_name, 2, type: :string
  field :mean_time_to_recovery_seconds, 3, type: :int32
  field :last_successful_run_at, 4, type: Google.Protobuf.Timestamp
  field :default_branch, 5, type: InternalApi.Velocity.Stats
  field :all_branches, 6, type: InternalApi.Velocity.Stats
  field :parallelism, 7, type: :int32
  field :deployments, 8, type: :int32
end

defmodule InternalApi.Velocity.Stats do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          all_count: integer,
          passed_count: integer,
          failed_count: integer,
          avg_seconds: integer,
          avg_seconds_successful: integer,
          queue_time_seconds: integer,
          queue_time_seconds_successful: integer
        }

  defstruct [
    :all_count,
    :passed_count,
    :failed_count,
    :avg_seconds,
    :avg_seconds_successful,
    :queue_time_seconds,
    :queue_time_seconds_successful
  ]

  field :all_count, 1, type: :int32
  field :passed_count, 2, type: :int32
  field :failed_count, 3, type: :int32
  field :avg_seconds, 4, type: :int32
  field :avg_seconds_successful, 5, type: :int32
  field :queue_time_seconds, 6, type: :int32
  field :queue_time_seconds_successful, 7, type: :int32
end

defmodule InternalApi.Velocity.DescribeDashboardItemRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field :id, 1, type: :string
end

defmodule InternalApi.Velocity.DescribeDashboardItemResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          item: InternalApi.Velocity.DashboardItem.t() | nil
        }

  defstruct [:item]

  field :item, 1, type: InternalApi.Velocity.DashboardItem
end

defmodule InternalApi.Velocity.DeleteDashboardItemRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field :id, 1, type: :string
end

defmodule InternalApi.Velocity.DeleteDashboardItemResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.DeleteMetricsDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field :id, 1, type: :string
end

defmodule InternalApi.Velocity.DeleteMetricsDashboardResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.ListMetricsDashboardsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t()
        }

  defstruct [:project_id]

  field :project_id, 1, type: :string
end

defmodule InternalApi.Velocity.ListMetricsDashboardsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboards: [InternalApi.Velocity.MetricsDashboard.t()]
        }

  defstruct [:dashboards]

  field :dashboards, 1, repeated: true, type: InternalApi.Velocity.MetricsDashboard
end

defmodule InternalApi.Velocity.DescribeMetricsDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t()
        }

  defstruct [:id]

  field :id, 1, type: :string
end

defmodule InternalApi.Velocity.DescribeMetricsDashboardResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard: InternalApi.Velocity.MetricsDashboard.t() | nil
        }

  defstruct [:dashboard]

  field :dashboard, 1, type: InternalApi.Velocity.MetricsDashboard
end

defmodule InternalApi.Velocity.MetricsDashboard do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          project_id: String.t(),
          organization_id: String.t(),
          inserted_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil,
          items: [InternalApi.Velocity.DashboardItem.t()]
        }

  defstruct [:id, :name, :project_id, :organization_id, :inserted_at, :updated_at, :items]

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :project_id, 3, type: :string
  field :organization_id, 4, type: :string
  field :inserted_at, 5, type: Google.Protobuf.Timestamp
  field :updated_at, 6, type: Google.Protobuf.Timestamp
  field :items, 7, repeated: true, type: InternalApi.Velocity.DashboardItem
end

defmodule InternalApi.Velocity.DashboardItem do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          metrics_dashboard_id: String.t(),
          branch_name: String.t(),
          pipeline_file_name: String.t(),
          inserted_at: Google.Protobuf.Timestamp.t() | nil,
          updated_at: Google.Protobuf.Timestamp.t() | nil,
          settings: InternalApi.Velocity.DashboardItemSettings.t() | nil,
          notes: String.t()
        }

  defstruct [
    :id,
    :name,
    :metrics_dashboard_id,
    :branch_name,
    :pipeline_file_name,
    :inserted_at,
    :updated_at,
    :settings,
    :notes
  ]

  field :id, 1, type: :string
  field :name, 2, type: :string
  field :metrics_dashboard_id, 3, type: :string
  field :branch_name, 4, type: :string
  field :pipeline_file_name, 5, type: :string
  field :inserted_at, 6, type: Google.Protobuf.Timestamp
  field :updated_at, 7, type: Google.Protobuf.Timestamp
  field :settings, 8, type: InternalApi.Velocity.DashboardItemSettings
  field :notes, 9, type: :string
end

defmodule InternalApi.Velocity.DashboardItemSettings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metric: InternalApi.Velocity.Metric.t(),
          goal: String.t()
        }

  defstruct [:metric, :goal]

  field :metric, 1, type: InternalApi.Velocity.Metric, enum: true
  field :goal, 2, type: :string
end

defmodule InternalApi.Velocity.CreateMetricsDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          project_id: String.t(),
          organization_id: String.t()
        }

  defstruct [:name, :project_id, :organization_id]

  field :name, 1, type: :string
  field :project_id, 2, type: :string
  field :organization_id, 3, type: :string
end

defmodule InternalApi.Velocity.CreateMetricsDashboardResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          dashboard: InternalApi.Velocity.MetricsDashboard.t() | nil
        }

  defstruct [:dashboard]

  field :dashboard, 1, type: InternalApi.Velocity.MetricsDashboard
end

defmodule InternalApi.Velocity.UpdateMetricsDashboardRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }

  defstruct [:id, :name]

  field :id, 1, type: :string
  field :name, 2, type: :string
end

defmodule InternalApi.Velocity.UpdateMetricsDashboardResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.CreateDashboardItemRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          metrics_dashboard_id: String.t(),
          branch_name: String.t(),
          pipeline_file_name: String.t(),
          settings: InternalApi.Velocity.DashboardItemSettings.t() | nil,
          notes: String.t()
        }

  defstruct [:name, :metrics_dashboard_id, :branch_name, :pipeline_file_name, :settings, :notes]

  field :name, 1, type: :string
  field :metrics_dashboard_id, 2, type: :string
  field :branch_name, 3, type: :string
  field :pipeline_file_name, 4, type: :string
  field :settings, 5, type: InternalApi.Velocity.DashboardItemSettings
  field :notes, 6, type: :string
end

defmodule InternalApi.Velocity.CreateDashboardItemResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          item: InternalApi.Velocity.DashboardItem.t() | nil
        }

  defstruct [:item]

  field :item, 1, type: InternalApi.Velocity.DashboardItem
end

defmodule InternalApi.Velocity.UpdateDashboardItemRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t()
        }

  defstruct [:id, :name]

  field :id, 1, type: :string
  field :name, 2, type: :string
end

defmodule InternalApi.Velocity.UpdateDashboardItemResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.ChangeDashboardItemNotesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: String.t(),
          notes: String.t()
        }

  defstruct [:id, :notes]

  field :id, 1, type: :string
  field :notes, 2, type: :string
end

defmodule InternalApi.Velocity.ChangeDashboardItemNotesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule InternalApi.Velocity.ListPipelinePerformanceMetricsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          pipeline_file_name: String.t(),
          branch_name: String.t(),
          aggregate: InternalApi.Velocity.MetricAggregation.t(),
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:project_id, :pipeline_file_name, :branch_name, :aggregate, :from_date, :to_date]

  field :project_id, 1, type: :string
  field :pipeline_file_name, 2, type: :string
  field :branch_name, 3, type: :string
  field :aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true
  field :from_date, 5, type: Google.Protobuf.Timestamp
  field :to_date, 6, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.ListPipelinePerformanceMetricsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          all_metrics: [InternalApi.Velocity.PerformanceMetric.t()],
          passed_metrics: [InternalApi.Velocity.PerformanceMetric.t()],
          failed_metrics: [InternalApi.Velocity.PerformanceMetric.t()]
        }

  defstruct [:all_metrics, :passed_metrics, :failed_metrics]

  field :all_metrics, 1, repeated: true, type: InternalApi.Velocity.PerformanceMetric
  field :passed_metrics, 2, repeated: true, type: InternalApi.Velocity.PerformanceMetric
  field :failed_metrics, 3, repeated: true, type: InternalApi.Velocity.PerformanceMetric
end

defmodule InternalApi.Velocity.PerformanceMetric do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil,
          count: integer,
          mean_seconds: integer,
          median_seconds: integer,
          min_seconds: integer,
          max_seconds: integer,
          std_dev_seconds: integer,
          p95_seconds: integer
        }

  defstruct [
    :from_date,
    :to_date,
    :count,
    :mean_seconds,
    :median_seconds,
    :min_seconds,
    :max_seconds,
    :std_dev_seconds,
    :p95_seconds
  ]

  field :from_date, 1, type: Google.Protobuf.Timestamp
  field :to_date, 2, type: Google.Protobuf.Timestamp
  field :count, 3, type: :int32
  field :mean_seconds, 4, type: :int32
  field :median_seconds, 5, type: :int32
  field :min_seconds, 6, type: :int32
  field :max_seconds, 7, type: :int32
  field :std_dev_seconds, 8, type: :int32
  field :p95_seconds, 9, type: :int32
end

defmodule InternalApi.Velocity.ListPipelineReliabilityMetricsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          pipeline_file_name: String.t(),
          branch_name: String.t(),
          aggregate: InternalApi.Velocity.MetricAggregation.t(),
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:project_id, :pipeline_file_name, :branch_name, :aggregate, :from_date, :to_date]

  field :project_id, 1, type: :string
  field :pipeline_file_name, 2, type: :string
  field :branch_name, 3, type: :string
  field :aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true
  field :from_date, 5, type: Google.Protobuf.Timestamp
  field :to_date, 6, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.ListPipelineReliabilityMetricsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metrics: [InternalApi.Velocity.ReliabilityMetric.t()]
        }

  defstruct [:metrics]

  field :metrics, 1, repeated: true, type: InternalApi.Velocity.ReliabilityMetric
end

defmodule InternalApi.Velocity.ReliabilityMetric do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil,
          all_count: integer,
          passed_count: integer,
          failed_count: integer
        }

  defstruct [:from_date, :to_date, :all_count, :passed_count, :failed_count]

  field :from_date, 1, type: Google.Protobuf.Timestamp
  field :to_date, 2, type: Google.Protobuf.Timestamp
  field :all_count, 3, type: :int32
  field :passed_count, 4, type: :int32
  field :failed_count, 5, type: :int32
end

defmodule InternalApi.Velocity.ListPipelineFrequencyMetricsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          pipeline_file_name: String.t(),
          branch_name: String.t(),
          aggregate: InternalApi.Velocity.MetricAggregation.t(),
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:project_id, :pipeline_file_name, :branch_name, :aggregate, :from_date, :to_date]

  field :project_id, 1, type: :string
  field :pipeline_file_name, 2, type: :string
  field :branch_name, 3, type: :string
  field :aggregate, 4, type: InternalApi.Velocity.MetricAggregation, enum: true
  field :from_date, 5, type: Google.Protobuf.Timestamp
  field :to_date, 6, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.ListPipelineFrequencyMetricsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          metrics: [InternalApi.Velocity.FrequencyMetric.t()]
        }

  defstruct [:metrics]

  field :metrics, 1, repeated: true, type: InternalApi.Velocity.FrequencyMetric
end

defmodule InternalApi.Velocity.FrequencyMetric do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil,
          all_count: integer
        }

  defstruct [:from_date, :to_date, :all_count]

  field :from_date, 1, type: Google.Protobuf.Timestamp
  field :to_date, 2, type: Google.Protobuf.Timestamp
  field :all_count, 3, type: :int32
end

defmodule InternalApi.Velocity.DescribeProjectPerformanceRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          pipeline_file_name: String.t(),
          branch_name: String.t(),
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:project_id, :pipeline_file_name, :branch_name, :from_date, :to_date]

  field :project_id, 1, type: :string
  field :pipeline_file_name, 2, type: :string
  field :branch_name, 3, type: :string
  field :from_date, 4, type: Google.Protobuf.Timestamp
  field :to_date, 5, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.DescribeProjectPerformanceResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          mean_time_to_recovery_seconds: integer,
          last_successful_run_at: Google.Protobuf.Timestamp.t() | nil,
          from_date: Google.Protobuf.Timestamp.t() | nil,
          to_date: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:mean_time_to_recovery_seconds, :last_successful_run_at, :from_date, :to_date]

  field :mean_time_to_recovery_seconds, 1, type: :int32
  field :last_successful_run_at, 2, type: Google.Protobuf.Timestamp
  field :from_date, 3, type: Google.Protobuf.Timestamp
  field :to_date, 4, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.DescribeProjectSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t()
        }

  defstruct [:project_id]

  field :project_id, 1, type: :string
end

defmodule InternalApi.Velocity.DescribeProjectSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: InternalApi.Velocity.Settings.t() | nil
        }

  defstruct [:settings]

  field :settings, 1, type: InternalApi.Velocity.Settings
end

defmodule InternalApi.Velocity.UpdateProjectSettingsRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          settings: InternalApi.Velocity.Settings.t() | nil
        }

  defstruct [:project_id, :settings]

  field :project_id, 1, type: :string
  field :settings, 2, type: InternalApi.Velocity.Settings
end

defmodule InternalApi.Velocity.UpdateProjectSettingsResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          settings: InternalApi.Velocity.Settings.t() | nil
        }

  defstruct [:settings]

  field :settings, 1, type: InternalApi.Velocity.Settings
end

defmodule InternalApi.Velocity.Settings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          cd_branch_name: String.t(),
          cd_pipeline_file_name: String.t(),
          ci_branch_name: String.t(),
          ci_pipeline_file_name: String.t()
        }

  defstruct [:cd_branch_name, :cd_pipeline_file_name, :ci_branch_name, :ci_pipeline_file_name]

  field :cd_branch_name, 1, type: :string
  field :cd_pipeline_file_name, 2, type: :string
  field :ci_branch_name, 3, type: :string
  field :ci_pipeline_file_name, 4, type: :string
end

defmodule InternalApi.Velocity.ListPipelineSummariesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_ids: [String.t()]
        }

  defstruct [:pipeline_ids]

  field :pipeline_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.Velocity.ListPipelineSummariesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_summaries: [InternalApi.Velocity.PipelineSummary.t()]
        }

  defstruct [:pipeline_summaries]

  field :pipeline_summaries, 1, repeated: true, type: InternalApi.Velocity.PipelineSummary
end

defmodule InternalApi.Velocity.ListJobSummariesRequest do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_ids: [String.t()]
        }

  defstruct [:job_ids]

  field :job_ids, 1, repeated: true, type: :string
end

defmodule InternalApi.Velocity.ListJobSummariesResponse do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_summaries: [InternalApi.Velocity.JobSummary.t()]
        }

  defstruct [:job_summaries]

  field :job_summaries, 1, repeated: true, type: InternalApi.Velocity.JobSummary
end

defmodule InternalApi.Velocity.PipelineSummary do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          summary: InternalApi.Velocity.Summary.t() | nil
        }

  defstruct [:pipeline_id, :summary]

  field :pipeline_id, 1, type: :string
  field :summary, 3, type: InternalApi.Velocity.Summary
end

defmodule InternalApi.Velocity.JobSummary do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          pipeline_id: String.t(),
          summary: InternalApi.Velocity.Summary.t() | nil
        }

  defstruct [:job_id, :pipeline_id, :summary]

  field :job_id, 1, type: :string
  field :pipeline_id, 2, type: :string
  field :summary, 4, type: InternalApi.Velocity.Summary
end

defmodule InternalApi.Velocity.Summary do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          total: integer,
          passed: integer,
          skipped: integer,
          error: integer,
          failed: integer,
          disabled: integer,
          duration: integer
        }

  defstruct [:total, :passed, :skipped, :error, :failed, :disabled, :duration]

  field :total, 1, type: :int32
  field :passed, 2, type: :int32
  field :skipped, 3, type: :int32
  field :error, 4, type: :int32
  field :failed, 5, type: :int32
  field :disabled, 6, type: :int32
  field :duration, 7, type: :int64
end

defmodule InternalApi.Velocity.PipelineSummaryAvailableEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          pipeline_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:pipeline_id, :timestamp]

  field :pipeline_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.JobSummaryAvailableEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          job_id: String.t(),
          timestamp: Google.Protobuf.Timestamp.t() | nil
        }

  defstruct [:job_id, :timestamp]

  field :job_id, 1, type: :string
  field :timestamp, 2, type: Google.Protobuf.Timestamp
end

defmodule InternalApi.Velocity.CollectPipelineMetricsEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          project_id: String.t(),
          organization_id: String.t(),
          pipeline_file_name: String.t(),
          branch_name: String.t(),
          metric_day: Google.Protobuf.Timestamp.t() | nil,
          timestamp: Google.Protobuf.Timestamp.t() | nil,
          project_name: String.t()
        }

  defstruct [
    :project_id,
    :organization_id,
    :pipeline_file_name,
    :branch_name,
    :metric_day,
    :timestamp,
    :project_name
  ]

  field :project_id, 1, type: :string
  field :organization_id, 2, type: :string
  field :pipeline_file_name, 3, type: :string
  field :branch_name, 4, type: :string
  field :metric_day, 5, type: Google.Protobuf.Timestamp
  field :timestamp, 6, type: Google.Protobuf.Timestamp
  field :project_name, 7, type: :string
end

defmodule InternalApi.Velocity.CollectSuperjerryJobReportEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          organization_id: String.t(),
          project_id: String.t(),
          pipeline_id: String.t(),
          job_id: String.t()
        }

  defstruct [:organization_id, :project_id, :pipeline_id, :job_id]

  field :organization_id, 1, type: :string
  field :project_id, 2, type: :string
  field :pipeline_id, 3, type: :string
  field :job_id, 4, type: :string
end

defmodule InternalApi.Velocity.PipelineMetricsService.Service do
  @moduledoc false
  use GRPC.Service, name: "InternalApi.Velocity.PipelineMetricsService"

  rpc :ListPipelineSummaries,
      InternalApi.Velocity.ListPipelineSummariesRequest,
      InternalApi.Velocity.ListPipelineSummariesResponse

  rpc :ListJobSummaries,
      InternalApi.Velocity.ListJobSummariesRequest,
      InternalApi.Velocity.ListJobSummariesResponse

  rpc :ListPipelinePerformanceMetrics,
      InternalApi.Velocity.ListPipelinePerformanceMetricsRequest,
      InternalApi.Velocity.ListPipelinePerformanceMetricsResponse

  rpc :ListPipelineReliabilityMetrics,
      InternalApi.Velocity.ListPipelineReliabilityMetricsRequest,
      InternalApi.Velocity.ListPipelineReliabilityMetricsResponse

  rpc :ListPipelineFrequencyMetrics,
      InternalApi.Velocity.ListPipelineFrequencyMetricsRequest,
      InternalApi.Velocity.ListPipelineFrequencyMetricsResponse

  rpc :DescribeProjectPerformance,
      InternalApi.Velocity.DescribeProjectPerformanceRequest,
      InternalApi.Velocity.DescribeProjectPerformanceResponse

  rpc :DescribeProjectSettings,
      InternalApi.Velocity.DescribeProjectSettingsRequest,
      InternalApi.Velocity.DescribeProjectSettingsResponse

  rpc :UpdateProjectSettings,
      InternalApi.Velocity.UpdateProjectSettingsRequest,
      InternalApi.Velocity.UpdateProjectSettingsResponse

  rpc :DescribeMetricsDashboard,
      InternalApi.Velocity.DescribeMetricsDashboardRequest,
      InternalApi.Velocity.DescribeMetricsDashboardResponse

  rpc :ListMetricsDashboards,
      InternalApi.Velocity.ListMetricsDashboardsRequest,
      InternalApi.Velocity.ListMetricsDashboardsResponse

  rpc :CreateMetricsDashboard,
      InternalApi.Velocity.CreateMetricsDashboardRequest,
      InternalApi.Velocity.CreateMetricsDashboardResponse

  rpc :UpdateMetricsDashboard,
      InternalApi.Velocity.UpdateMetricsDashboardRequest,
      InternalApi.Velocity.UpdateMetricsDashboardResponse

  rpc :DeleteMetricsDashboard,
      InternalApi.Velocity.DeleteMetricsDashboardRequest,
      InternalApi.Velocity.DeleteMetricsDashboardResponse

  rpc :CreateDashboardItem,
      InternalApi.Velocity.CreateDashboardItemRequest,
      InternalApi.Velocity.CreateDashboardItemResponse

  rpc :UpdateDashboardItem,
      InternalApi.Velocity.UpdateDashboardItemRequest,
      InternalApi.Velocity.UpdateDashboardItemResponse

  rpc :DeleteDashboardItem,
      InternalApi.Velocity.DeleteDashboardItemRequest,
      InternalApi.Velocity.DeleteDashboardItemResponse

  rpc :DescribeDashboardItem,
      InternalApi.Velocity.DescribeDashboardItemRequest,
      InternalApi.Velocity.DescribeDashboardItemResponse

  rpc :ChangeDashboardItemNotes,
      InternalApi.Velocity.ChangeDashboardItemNotesRequest,
      InternalApi.Velocity.ChangeDashboardItemNotesResponse

  rpc :FetchOrganizationHealth,
      InternalApi.Velocity.OrganizationHealthRequest,
      InternalApi.Velocity.OrganizationHealthResponse

  rpc :ListFlakyTestsFilters,
      InternalApi.Velocity.ListFlakyTestsFiltersRequest,
      InternalApi.Velocity.ListFlakyTestsFiltersResponse

  rpc :CreateFlakyTestsFilter,
      InternalApi.Velocity.CreateFlakyTestsFilterRequest,
      InternalApi.Velocity.CreateFlakyTestsFilterResponse

  rpc :RemoveFlakyTestsFilter,
      InternalApi.Velocity.RemoveFlakyTestsFilterRequest,
      InternalApi.Velocity.RemoveFlakyTestsFilterResponse

  rpc :UpdateFlakyTestsFilter,
      InternalApi.Velocity.UpdateFlakyTestsFilterRequest,
      InternalApi.Velocity.UpdateFlakyTestsFilterResponse

  rpc :InitializeFlakyTestsFilters,
      InternalApi.Velocity.InitializeFlakyTestsFiltersRequest,
      InternalApi.Velocity.InitializeFlakyTestsFiltersResponse
end

defmodule InternalApi.Velocity.PipelineMetricsService.Stub do
  @moduledoc false
  use GRPC.Stub, service: InternalApi.Velocity.PipelineMetricsService.Service
end
