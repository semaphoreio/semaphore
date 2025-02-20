defmodule Front.Models.ProjectMetrics do
  @moduledoc """
  This model is used to fetch metric data for a project.
  """

  alias Front.Clients.Velocity, as: VelocityClient
  alias Front.Models.ProjectMetrics
  alias InternalApi.Velocity, as: API
  require Logger

  @type aggregate :: :daily | :range
  @type opts :: [
          aggregate: aggregate(),
          from_date: Date.t(),
          to_date: Date.t()
        ]

  @type metric_spec ::
          {project_id :: Ecto.UUID.t(), pipeline_file_name :: String.t(),
           branch_name :: String.t()}

  @spec pipeline_performance(metric_spec :: metric_spec(), opts :: opts()) ::
          {:ok, ProjectMetrics.PipelinePerformance.t()} | {:error, any()}
  def pipeline_performance({project_id, pipeline_file_name, branch_name}, opts \\ []) do
    opts = decorate_opts(opts)

    VelocityClient.list_pipeline_performance_metrics(%API.ListPipelinePerformanceMetricsRequest{
      project_id: project_id,
      pipeline_file_name: pipeline_file_name,
      branch_name: branch_name,
      aggregate: opts[:aggregate],
      from_date: opts[:from_date],
      to_date: opts[:to_date]
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.PipelinePerformance.from_proto(response)}

      error ->
        Logger.error("Error fetching pipeline performance metrics: #{inspect(error)}")
        error
    end
  end

  @spec pipeline_frequency(metric_spec :: metric_spec(), opts :: opts()) ::
          {:ok, ProjectMetrics.PipelineFrequency.t()} | {:error, any()}
  def pipeline_frequency({project_id, pipeline_file_name, branch_name}, opts \\ []) do
    opts = decorate_opts(opts)

    VelocityClient.list_pipeline_frequency_metrics(%API.ListPipelineFrequencyMetricsRequest{
      project_id: project_id,
      pipeline_file_name: pipeline_file_name,
      branch_name: branch_name,
      aggregate: opts[:aggregate],
      from_date: opts[:from_date],
      to_date: opts[:to_date]
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.PipelineFrequency.from_proto(response)}

      error ->
        Logger.error("Error fetching pipeline frequency metrics: #{inspect(error)}")
        error
    end
  end

  @spec pipeline_reliability(metric_spec :: metric_spec(), opts :: opts()) ::
          {:ok, ProjectMetrics.PipelineReliability.t()} | {:error, any()}
  def pipeline_reliability({project_id, pipeline_file_name, branch_name}, opts \\ []) do
    opts = decorate_opts(opts)

    VelocityClient.list_pipeline_reliability_metrics(%API.ListPipelineReliabilityMetricsRequest{
      project_id: project_id,
      branch_name: branch_name,
      pipeline_file_name: pipeline_file_name,
      aggregate: opts[:aggregate],
      from_date: opts[:from_date],
      to_date: opts[:to_date]
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.PipelineReliability.from_proto(response)}

      error ->
        Logger.error("Error fetching pipeline reliability metrics: #{inspect(error)}")
        error
    end
  end

  @spec project_performance(metric_spec :: metric_spec(), opts :: opts()) ::
          {:ok, ProjectMetrics.ProjectPerformance.t()} | {:error, any()}
  def project_performance({project_id, pipeline_file_name, branch_name}, opts \\ []) do
    opts = decorate_opts(opts)

    VelocityClient.describe_project_performance(%API.DescribeProjectPerformanceRequest{
      project_id: project_id,
      pipeline_file_name: pipeline_file_name,
      branch_name: branch_name,
      from_date: opts[:from_date],
      to_date: opts[:to_date]
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.ProjectPerformance.from_proto(response)}

      error ->
        Logger.error("Error fetching project performance metrics: #{inspect(error)}")
        error
    end
  end

  def insights_project_settings(project_id) do
    VelocityClient.describe_project_settings(%API.DescribeProjectSettingsRequest{
      project_id: project_id
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.InsightsProjectSettings.from_proto(response)}

      error ->
        Logger.error("Error fetching project settings: #{inspect(error)}")
        error
    end
  end

  def update_insights_project_settings(project_id, settings) do
    VelocityClient.update_insights_project_settings(%API.UpdateProjectSettingsRequest{
      project_id: project_id,
      settings: %API.Settings{
        cd_branch_name: settings.cd_branch_name,
        cd_pipeline_file_name: settings.cd_pipeline_file_name,
        ci_branch_name: settings.ci_branch_name,
        ci_pipeline_file_name: settings.ci_pipeline_file_name
      }
    })
    |> case do
      {:ok, response} ->
        {:ok, ProjectMetrics.InsightsProjectSettings.from_proto(response)}

      error ->
        Logger.error("Error updating project settings: #{inspect(error)}")
        error
    end
  end

  @spec decorate_opts(opts) :: [
          aggregate: API.MetricAggregation.t(),
          from_date: Google.Protobuf.Timestamp.t(),
          to_date: Google.Protobuf.Timestamp.t()
        ]
  defp decorate_opts(opts) do
    [
      from_date: to_grpc_timestamp(opts[:from_date]),
      to_date: to_grpc_timestamp(opts[:to_date]),
      aggregate: to_grpc_aggregate(opts[:aggregate])
    ]
  end

  @spec to_grpc_timestamp(date :: Date.t()) :: Google.Protobuf.Timestamp.t()
  defp to_grpc_timestamp(date) do
    Google.Protobuf.Timestamp.new(%{
      seconds: Timex.to_unix(date)
    })
  end

  @spec to_grpc_aggregate(value :: aggregate) :: API.MetricAggregation.t()
  defp to_grpc_aggregate(value) do
    value
    |> case do
      :daily ->
        API.MetricAggregation.value(:DAILY)

      :range ->
        API.MetricAggregation.value(:RANGE)

      _ ->
        Logger.warn("Unknown aggregate: '#{value}', defaulting to range")
        API.MetricAggregation.value(:RANGE)
    end
  end
end
