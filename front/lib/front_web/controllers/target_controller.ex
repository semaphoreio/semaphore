defmodule FrontWeb.TargetController do
  use FrontWeb, :controller

  alias Front.Audit
  alias Front.Models.Switch
  alias FrontWeb.Plugs.{FetchPermissions, PageAccess, PutProjectAssigns}

  plug(:put_layout, false)
  plug(PutProjectAssigns)
  plug(FetchPermissions, scope: "project")
  plug(PageAccess, permissions: "project.job.rerun")

  def trigger(conn, params) do
    Watchman.benchmark("trigger.duration", fn ->
      switch_id = params["switch_id"]
      name = params["name"]
      user_id = conn.assigns.user_id
      tracing_headers = conn.assigns.tracing_headers

      switch = Switch.find(switch_id, user_id)
      target = Switch.find_target_by_name(switch, name)
      parameters = parse_target_parameters(conn)

      log_promotion(conn, name, switch, parameters)

      case Switch.Target.trigger(target, user_id, parameters, tracing_headers) do
        {:ok, _} ->
          text(conn, "Target '#{name}' triggered.")

        {:error, code, msg} ->
          conn
          |> put_status(error_http_status(code))
          |> json(%{code: to_string(code), message: error_message(code, msg)})

        {:error, msg} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{code: "INTERNAL", message: error_message(:INTERNAL, msg)})
      end
    end)
  end

  defp log_promotion(conn, name, switch, parameters) do
    conn
    |> Audit.new(:Pipeline, :Promoted)
    |> Audit.add(:resource_name, name)
    |> Audit.add(:description, log_description(name, parameters))
    |> Audit.metadata(project_id: conn.assigns.project.id)
    |> Audit.metadata(project_name: conn.assigns.project.name)
    |> Audit.metadata(branch_name: conn.assigns.workflow.branch_name)
    |> Audit.metadata(workflow_id: conn.assigns.workflow.id)
    |> Audit.metadata(commit_sha: conn.assigns.workflow.commit_sha)
    |> Audit.metadata(pipeline_id: switch.pipeline_id)
    |> Audit.log()
  end

  defp log_description(name, []) do
    "Triggered a promotion to #{name}"
  end

  defp log_description(name, parameters) do
    parameter_description =
      parameters
      |> Enum.map_join(" ", fn p -> "#{p.name}=#{p.value}" end)

    log_description(name, []) <> " with parameters " <> parameter_description
  end

  defp parse_target_parameters(conn) do
    (conn.body_params["parameters"] || [])
    |> Enum.map(fn {key, value} ->
      InternalApi.Gofer.EnvVariable.new(name: key, value: value)
    end)
  end

  defp error_http_status(:REFUSED), do: :conflict
  defp error_http_status(:NOT_FOUND), do: :not_found
  defp error_http_status(:BAD_PARAM), do: :bad_request
  defp error_http_status(:MALFORMED), do: :bad_request
  defp error_http_status(_), do: :internal_server_error

  defp error_message(_code, msg) when is_binary(msg) and msg != "", do: msg
  defp error_message(:REFUSED, _), do: "Promotion request was refused."
  defp error_message(:NOT_FOUND, _), do: "Promotion target was not found."
  defp error_message(:BAD_PARAM, _), do: "Promotion request is invalid."
  defp error_message(:MALFORMED, _), do: "Promotion request is malformed."
  defp error_message(:INTERNAL, _), do: "Failed to trigger promotion."
  defp error_message(_, _), do: "Failed to trigger promotion."
end
