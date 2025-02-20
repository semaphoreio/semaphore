defmodule FrontWeb.Insights.MetricsController do
  use FrontWeb, :controller
  alias Front.Audit
  alias Front.Models
  alias FrontWeb.Plugs
  alias Models.ProjectMetrics

  require Logger

  plug(
    Plugs.ProjectAuthorization
    when action in [:index, :get_insights_project_settings, :update_insights_project_settings]
  )

  @type insight_type ::
          :pipeline_performance
          | :pipeline_frequency
          | :pipeline_reliability
          | :summary

  def index(conn, params) do
    with {:ok, metric_spec} <- metric_spec(conn, params),
         metric_opts <- fetch_default_opts(conn, params),
         insight_type <- fetch_insight_type(conn, params) do
      do_index(conn, metric_spec, metric_opts, insight_type)
    else
      {:error, %GRPC.RPCError{message: message}} ->
        json(conn, %{error: message})

      {:error, _} ->
        json(conn, %{error: "Unhandled error."})
    end
  end

  defp metric_spec(conn, params) do
    cond do
      Map.has_key?(params, "cd") ->
        fetch_cd_metric_spec(conn, params)

      Map.has_key?(params, "custom_dashboards") ->
        fetch_custom_dashboard_metric_spec(conn, params)

      true ->
        fetch_metric_spec(conn, params)
    end
  end

  defp do_index(conn, metric_spec, metric_opts, insight_type) do
    insight_type
    |> case do
      :pipeline_performance ->
        pipeline_performance_metrics(conn, metric_spec, metric_opts)

      :pipeline_frequency ->
        pipeline_frequency_metrics(conn, metric_spec, metric_opts)

      :pipeline_reliability ->
        pipeline_reliability_metrics(conn, metric_spec, metric_opts)

      :summary ->
        summary(conn, metric_spec, metric_opts)
    end
  end

  @spec pipeline_performance_metrics(
          conn :: Plug.Conn.t(),
          metric_spec :: ProjectMetrics.metric_spec(),
          ProjectMetrics.opts()
        ) :: Plug.Conn.t()
  defp pipeline_performance_metrics(conn, metric_spec, metric_opts) do
    with {:ok, metrics} <- ProjectMetrics.pipeline_performance(metric_spec, metric_opts) do
      conn
      |> render("pipeline_performance.json", %{metrics: metrics})
    end
  end

  @spec pipeline_frequency_metrics(
          conn :: Plug.Conn.t(),
          metric_spec :: ProjectMetrics.metric_spec(),
          ProjectMetrics.opts()
        ) ::
          Plug.Conn.t()
  defp pipeline_frequency_metrics(conn, metric_spec, metric_opts) do
    with {:ok, metrics} <- ProjectMetrics.pipeline_frequency(metric_spec, metric_opts) do
      conn
      |> render("pipeline_frequency.json", %{metrics: metrics})
    end
  end

  @spec pipeline_reliability_metrics(
          conn :: Plug.Conn.t(),
          metric_spec :: ProjectMetrics.metric_spec(),
          ProjectMetrics.opts()
        ) :: Plug.Conn.t()
  defp pipeline_reliability_metrics(conn, metric_spec, metric_opts) do
    with {:ok, metrics} <- ProjectMetrics.pipeline_reliability(metric_spec, metric_opts) do
      conn
      |> render("pipeline_reliability.json", %{metrics: metrics})
    end
  end

  @spec summary(
          conn :: Plug.Conn.t(),
          metric_spec :: ProjectMetrics.metric_spec(),
          ProjectMetrics.opts()
        ) ::
          Plug.Conn.t()
  defp summary(conn, metric_spec, metric_opts) do
    with metric_opts <- put_in(metric_opts[:aggregate], :range),
         {:ok, performance} <- ProjectMetrics.pipeline_performance(metric_spec, metric_opts),
         {:ok, frequency} <- ProjectMetrics.pipeline_frequency(metric_spec, metric_opts),
         {:ok, reliability} <- ProjectMetrics.pipeline_reliability(metric_spec, metric_opts),
         {:ok, project} <- ProjectMetrics.project_performance(metric_spec, metric_opts) do
      conn
      |> render("summary.json", %{
        performance: performance,
        frequency: frequency,
        reliability: reliability,
        project: project
      })
    end
  end

  def project_performance_metrics(conn, metric_spec, metric_opts) do
    with metric_opts <- put_in(metric_opts[:aggregate], :range),
         {:ok, metrics} <- ProjectMetrics.project_performance(metric_spec, metric_opts) do
      conn
      |> render("project_performance.json", %{metrics: metrics})
    end
  end

  @spec fetch_insight_type(conn :: Plug.Conn.t(), params :: Map.t()) :: insight_type()
  defp fetch_insight_type(_conn, params) do
    params
    |> Map.get("insight_type")
    |> case do
      "pipeline_performance" ->
        :pipeline_performance

      "pipeline_frequency" ->
        :pipeline_frequency

      "pipeline_reliability" ->
        :pipeline_reliability

      "summary" ->
        :summary

      _ ->
        :summary
    end
  end

  @spec fetch_default_opts(
          conn :: Plug.Conn.t(),
          params :: Map.t(),
          overrides :: ProjectMetrics.opts()
        ) ::
          ProjectMetrics.opts()
  defp fetch_default_opts(_conn, params, overrides \\ []) do
    thirty_days_ago = Date.utc_today() |> Date.add(-30)
    yesterday = Date.utc_today() |> Date.add(-1)

    date_range =
      with {:ok, from} <- Date.from_iso8601(params["from_date"] || ""),
           {:ok, to} <- Date.from_iso8601(params["to_date"] || "") do
        {from, to}
      else
        {:error, _} -> {thirty_days_ago, yesterday}
      end

    {from_date, to_date} = date_range

    aggr = params["aggregate"] || "daily" |> String.downcase()
    aggregate = if aggr == "range", do: :range, else: :daily

    [
      aggregate: aggregate,
      from_date: from_date,
      to_date: to_date
    ]
    |> Keyword.merge(overrides)
  end

  @spec fetch_metric_spec(
          conn :: Plug.Conn.t(),
          params :: Map.t()
        ) :: ProjectMetrics.metric_spec()
  defp fetch_metric_spec(conn, params) do
    %Front.Models.Project{} = project = conn.assigns.project

    {file_name, branch} =
      ProjectMetrics.insights_project_settings(project.id)
      |> case do
        {:ok, settings} ->
          {settings.ci_pipeline_file_name, settings.ci_branch_name}

        error ->
          Logger.error("Error fetch project settings: #{inspect(error)}")
          {project.initial_pipeline_file, project.repo_default_branch}
      end

    project_id = project.id
    ppl_file_name = if file_name == "", do: project.initial_pipeline_file, else: file_name

    {:ok, {project_id, ppl_file_name, branch_name(params, branch, project.repo_default_branch)}}
  end

  defp fetch_cd_metric_spec(conn, _params) do
    %Front.Models.Project{} = project = conn.assigns.project

    ProjectMetrics.insights_project_settings(project.id)
    |> case do
      {:ok, settings} ->
        {:ok, {project.id, settings.cd_pipeline_file_name, settings.cd_branch_name}}

      error ->
        Logger.error("Error fetch project settings: #{inspect(error)}")
        error
    end
  end

  defp fetch_custom_dashboard_metric_spec(conn, params) do
    %Front.Models.Project{} = project = conn.assigns.project

    project_id = project.id

    ppl_file_name =
      params
      |> Map.get("ppl_file_name", project.initial_pipeline_file)

    branch_name =
      params
      |> Map.get("branch", "")

    {:ok, {project_id, ppl_file_name, branch_name}}
  end

  def get_insights_project_settings(conn, params) do
    Watchman.benchmark("insights.get_insights_project_settings.duration", fn ->
      Map.get(params, "name_or_id")
      |> project_settings(conn)
    end)
  end

  defp project_settings(project_id, conn) do
    with {:ok, settings} <- ProjectMetrics.insights_project_settings(project_id) do
      conn
      |> render("insights_project_settings.json", %{settings: settings})
    end
  end

  def update_insights_project_settings(conn, params) do
    Watchman.benchmark("insights.update_insights_project_settings.duration", fn ->
      project_id = Map.get(params, "name_or_id")
      settings = settings_from_body(conn.body_params)

      conn
      |> update_insights_settings(project_id, settings)
    end)
  end

  def available_metrics_dates(conn, _params) do
    conn |> json(%{available_dates: available()})
  end

  defp available do
    [{:day, 30}, {:day, 60}, {:day, 90}, {:month, 0}, {:month, 1}, {:month, 2}, {:month, 3}]
    |> Enum.map(&get_datetime_range_past/1)
  end

  defp get_datetime_range_past({:day, n}) do
    today = Date.utc_today()
    from = Date.add(today, -n)

    %{label: "#{n} days", from: from, to: today}
  end

  defp get_datetime_range_past({:month, n}) do
    today = Date.utc_today()
    from = today |> Timex.shift(months: -n) |> Date.beginning_of_month()

    to = from |> Date.end_of_month()

    label = if n == 0, do: "Current month", else: Timex.format!(from, "{Mshort} {YYYY}")

    %{label: label, from: from, to: to}
  end

  defp log_update(conn, project_id, settings) do
    conn
    |> Audit.new(:ProjectInsightsSettings, :Modified)
    |> Audit.add(:resource_name, "Insight Settings")
    |> Audit.add(:description, "Update Insights Settings for Project")
    |> Audit.metadata(project_id: project_id)
    |> Audit.metadata(cd_branch_name: settings.cd_branch_name)
    |> Audit.metadata(cd_pipeline_file_name: settings.cd_pipeline_file_name)
    |> Audit.metadata(ci_branch_name: settings.ci_branch_name)
    |> Audit.metadata(ci_pipeline_file_name: settings.ci_pipeline_file_name)
    |> Audit.log()
  end

  defp update_insights_settings(conn, project_id, settings) do
    case ProjectMetrics.update_insights_project_settings(project_id, settings) do
      {:ok, s} ->
        log_update(conn, project_id, settings)

        conn
        |> put_status(201)
        |> render("insights_project_settings.json", %{settings: s})

      {:error, msg} ->
        conn
        |> put_status(422)
        |> json(%{error: msg})
    end
  end

  defp settings_from_body(params) do
    %{
      cd_branch_name: params["cd_branch_name"],
      cd_pipeline_file_name: params["cd_pipeline_file_name"],
      ci_branch_name: params["ci_branch_name"],
      ci_pipeline_file_name: params["ci_pipeline_file_name"]
    }
  end

  defp branch_name(params, settings_branch, repo_default_branch) do
    cond do
      Map.get(params, "branch") == "all" ->
        ""

      settings_branch != "" ->
        settings_branch

      true ->
        repo_default_branch
    end
  end
end
