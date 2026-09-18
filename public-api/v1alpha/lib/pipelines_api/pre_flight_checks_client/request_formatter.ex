defmodule PipelinesAPI.PreFlightChecksClient.RequestFormatter do
  @moduledoc """
  Module formats the request using data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with PreFlightChecksHub service.

  The pre-flight check level is derived from the presence of the project_id param:
  when it is given the request is scoped to a project, otherwise to the organization.
  """

  alias InternalApi.PreFlightChecksHub.{ApplyRequest, DescribeRequest, DestroyRequest}
  alias PipelinesAPI.Util.ToTuple
  alias Plug.Conn

  def form_describe_request(params, conn) when is_map(params) do
    %{
      level: level(params),
      organization_id: org_id(conn),
      project_id: project_id(params)
    }
    |> Util.Proto.deep_new(DescribeRequest)
  catch
    error -> error
  end

  def form_describe_request(error = {:error, _}, _conn), do: error

  def form_apply_request(params = %{"commands" => commands}, conn)
      when is_map(params) and is_list(commands) and length(commands) > 0 do
    %{
      level: level(params),
      organization_id: org_id(conn),
      project_id: project_id(params),
      requester_id: requester_id(conn),
      pre_flight_checks: pre_flight_checks(params)
    }
    |> Util.Proto.deep_new(ApplyRequest)
  catch
    error -> error
  end

  def form_apply_request(error = {:error, _}, _conn), do: error

  def form_apply_request(_params, _conn),
    do: ToTuple.user_error("commands must be a non-empty list of strings")

  def form_destroy_request(params, conn) when is_map(params) do
    %{
      level: level(params),
      organization_id: org_id(conn),
      project_id: project_id(params),
      requester_id: requester_id(conn)
    }
    |> Util.Proto.deep_new(DestroyRequest)
  catch
    error -> error
  end

  def form_destroy_request(error = {:error, _}, _conn), do: error

  # private functions

  defp pre_flight_checks(params = %{"project_id" => project_id})
       when is_binary(project_id) and project_id != "",
       do: %{project_pfc: pfc_spec(params)}

  defp pre_flight_checks(params), do: %{organization_pfc: pfc_spec(params)}

  defp pfc_spec(params) do
    %{
      commands: params["commands"],
      secrets: params["secrets"] || []
    }
    |> put_agent(params["agent"])
  end

  defp put_agent(spec, agent) when is_map(agent) do
    Map.put(spec, :agent, %{
      machine_type: agent["machine_type"] || "",
      os_image: agent["os_image"] || ""
    })
  end

  defp put_agent(spec, _agent), do: spec

  defp level(%{"project_id" => project_id}) when is_binary(project_id) and project_id != "",
    do: :PROJECT

  defp level(_params), do: :ORGANIZATION

  defp project_id(params), do: params["project_id"] || ""

  defp org_id(conn), do: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

  defp requester_id(conn), do: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
end
