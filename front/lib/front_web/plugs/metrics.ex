defmodule FrontWeb.Plugs.Metrics do
  @moduledoc """
  Measures the response time of every phoenix action.

  Metrics are sent in the following format:

    "web.response.duration/{{status_cide}}" tagged_with: [<controller-name>, <action>]

  Example:

    "web.response.duration" tagged_with: ["FrontWeb_DashboardController", "show"]
  """

  # DEPRECATED
  @metric_name "phoenix.response.time"
  @metric_prefix "web.response"
  @metric_prefix_external "response"
  @actions_for_external_metrics_mapping %{
    {FrontWeb.DashboardController, :workflows} => :"home-page",
    {FrontWeb.ProjectController, :workflows} => :"project-page",
    {FrontWeb.BranchController, :workflows} => :"branch-page",
    {FrontWeb.WorkflowController, :show} => :"workflow-page",
    {FrontWeb.JobController, :show} => :"job-page"
  }

  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    start = System.monotonic_time()

    register_before_send(conn, fn conn ->
      stop = System.monotonic_time()
      spawn(fn -> submit_metrics(conn, start, stop) end)

      conn
    end)
  end

  def submit_metrics(conn, start, stop) do
    duration = System.convert_time_unit(stop - start, :native, :microsecond)

    controller = Map.get(conn.private, :phoenix_controller)
    action = Map.get(conn.private, :phoenix_action)

    if controller && action do
      tags = [
        String.replace(Atom.to_string(controller), ".", "_"),
        String.replace(Atom.to_string(action), ".", "_")
      ]

      Watchman.submit({@metric_name, tags}, duration, :timing)
      Watchman.submit({"#{@metric_prefix}.duration", tags}, duration, :timing)

      group = status_metric_group(conn.status)

      page = Map.get(@actions_for_external_metrics_mapping, {controller, action})

      if page != nil do
        Watchman.submit(
          {:external, {"#{@metric_prefix_external}.duration", [page: page]}},
          duration,
          :timing
        )

        Watchman.increment(
          {:external, {"#{@metric_prefix_external}", [page: page, status_code: group]}}
        )
      end

      increment("#{@metric_prefix}.status_group", tags ++ [group])
      increment("#{@metric_prefix}.status", tags ++ [conn.status])
    end
  end

  defp status_metric_group(number) when number >= 100 and number <= 199, do: "1xx"
  defp status_metric_group(number) when number >= 200 and number <= 299, do: "2xx"
  defp status_metric_group(number) when number >= 300 and number <= 399, do: "3xx"
  defp status_metric_group(number) when number >= 400 and number <= 499, do: "4xx"
  defp status_metric_group(number) when number >= 500 and number <= 599, do: "5xx"

  defp increment(name, tags), do: Watchman.increment({name, tags})
end
