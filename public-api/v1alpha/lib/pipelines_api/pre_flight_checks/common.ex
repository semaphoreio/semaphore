defmodule PipelinesAPI.PreFlightChecks.Common do
  @moduledoc """
  Utility functions needed to handle pre-flight checks operations, like feature
  gating, parameter checks and audit logging of the mutations.
  """

  use Plug.Builder

  alias PipelinesAPI.Audit
  alias Plug.Conn

  @plans_docs_link "https://semaphoreci.com/pricing"

  def has_pre_flight_checks_enabled(conn, _opts) do
    with org_id <- Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0),
         true <- FeatureProvider.feature_enabled?(:pre_flight_checks, param: org_id) do
      conn
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> resp(
          403,
          "The pre flight checks feature is not enabled for your organization. See more details here: #{@plans_docs_link}"
        )
        |> halt
    end
  end

  def is_non_empty_list_of_strings(list) when is_list(list) and length(list) > 0,
    do: Enum.all?(list, &is_binary/1)

  def is_non_empty_list_of_strings(_list), do: false

  def is_list_of_strings(nil), do: true

  def is_list_of_strings(list) when is_list(list), do: Enum.all?(list, &is_binary/1)

  def is_list_of_strings(_list), do: false

  def is_agent(nil), do: true

  def is_agent(agent) when is_map(agent) do
    is_binary(agent["machine_type"]) and
      (is_nil(agent["os_image"]) or is_binary(agent["os_image"]))
  end

  def is_agent(_agent), do: false

  def audit_apply(conn = %{params: %{"project_id" => project_id}})
      when is_binary(project_id) and project_id != "",
      do: log_project_event(conn, project_id, "Applied project pre-flight checks")

  def audit_apply(conn),
    do: log_organization_event(conn, "Applied organization pre-flight checks")

  def audit_delete(conn = %{params: %{"project_id" => project_id}})
      when is_binary(project_id) and project_id != "",
      do: log_project_event(conn, project_id, "Deleted project pre-flight checks")

  def audit_delete(conn),
    do: log_organization_event(conn, "Deleted organization pre-flight checks")

  defp log_project_event(conn, project_id, description) do
    conn
    |> Audit.new(:Project, :Modified)
    |> Audit.add(description: description)
    |> Audit.add(resource_id: project_id)
    |> Audit.metadata(requester_id: requester_id(conn), project_id: project_id)
    |> Audit.log()
  end

  defp log_organization_event(conn, description) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    conn
    |> Audit.new(:Organization, :Modified)
    |> Audit.add(description: description)
    |> Audit.add(resource_id: org_id)
    |> Audit.metadata(requester_id: requester_id(conn))
    |> Audit.log()
  end

  defp requester_id(conn), do: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
end
