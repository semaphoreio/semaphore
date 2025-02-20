defmodule PipelinesAPI.SelfHostedHubClient.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with SelHostedHub service.
  """

  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin

  alias InternalApi.SelfHosted.{
    CreateRequest,
    UpdateRequest,
    DescribeRequest,
    DescribeAgentRequest,
    DisableAllAgentsRequest,
    DeleteAgentTypeRequest,
    ListRequest,
    ListAgentsRequest,
    AgentNameSettings
  }

  @on_load :load_atoms

  defp load_atoms() do
    [
      InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin
    ]
    |> Enum.each(&Code.ensure_loaded/1)
  end

  # Create

  def form_create_request(params, conn) when is_map(params) do
    case get_in(params, ["metadata", "name"]) do
      nil ->
        ToTuple.user_error("Name must be provided")

      name ->
        common_params(conn, params, name)
        |> CreateRequest.new()
        |> ToTuple.ok()
    end
  catch
    error -> error
  end

  def form_create_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_update_request(params, conn) when is_map(params) do
    case get_in(params, ["metadata", "name"]) do
      nil ->
        ToTuple.user_error("Name must be provided")

      name ->
        header_params(conn)
        |> Map.merge(%{
          name: name,
          agent_type: InternalApi.SelfHosted.AgentType.new(common_params(conn, params, name))
        })
        |> UpdateRequest.new()
        |> ToTuple.ok()
    end
  catch
    error -> error
  end

  def form_update_request(_, _), do: ToTuple.internal_error("Internal error")

  # Describe

  def form_describe_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      name: params |> Map.get("agent_type_name", "")
    }
    |> DescribeRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_describe_request(_, _), do: ToTuple.internal_error("Internal error")

  # Describe agent

  def form_describe_agent_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      name: params |> Map.get("agent_name", "")
    }
    |> DescribeAgentRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_describe_agent_request(_, _), do: ToTuple.internal_error("Internal error")

  # Delete

  def form_delete_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      name: params |> Map.get("agent_type_name", "")
    }
    |> DeleteAgentTypeRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_delete_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_disable_all_request(params, conn) when is_map(params) do
    case to_boolean(Map.get(params, "only_idle", true)) do
      {:ok, value} ->
        %{
          organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
          agent_type: params |> Map.get("agent_type_name", ""),
          only_idle: value
        }
        |> DisableAllAgentsRequest.new()
        |> ToTuple.ok()

      {:error, message} ->
        ToTuple.user_error("Invalid 'only_idle': #{message}")
    end
  catch
    error -> error
  end

  def form_disable_all_request(_, _), do: ToTuple.internal_error("Internal error")

  # List

  def form_list_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      page: params |> Map.get("page", 1) |> to_int("page")
    }
    |> ListRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_list_request(_, _), do: ToTuple.internal_error("Internal error")

  # List agents

  def form_list_agents_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      agent_type_name: params |> Map.get("agent_type", ""),
      page_size: params |> Map.get("page_size", 200) |> to_int("page_size"),
      cursor: params |> Map.get("cursor", "")
    }
    |> ListAgentsRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_list_agents_request(_, _), do: ToTuple.internal_error("Internal error")

  defp to_int(val, _field) when is_integer(val), do: val

  defp to_int(val, field) do
    case Integer.parse(val) do
      {n, ""} ->
        n

      _ ->
        "Invalid value of '#{field}' param: #{inspect(val)} - needs to be integer."
        |> ToTuple.user_error()
        |> throw()
    end
  end

  defp to_boolean(false), do: {:ok, false}
  defp to_boolean("false"), do: {:ok, false}
  defp to_boolean(true), do: {:ok, true}
  defp to_boolean("true"), do: {:ok, true}
  defp to_boolean(value), do: {:error, "'#{value}' is not a boolean."}

  defp header_params(conn) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      requester_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    }
  end

  defp common_params(conn, params, name) do
    header_params(conn)
    |> Map.merge(%{
      name: name,
      agent_name_settings: agent_name_settings(get_in(params, ["spec", "agent_name_settings"]))
    })
  end

  defp agent_name_settings(nil), do: nil

  defp agent_name_settings(from_request) do
    origin =
      Map.get(from_request, "assignment_origin", "assignment_origin_agent")
      |> String.upcase()
      |> String.to_existing_atom()

    if Map.has_key?(from_request, "aws") and is_map(from_request["aws"]) do
      AgentNameSettings.new(
        assignment_origin: AssignmentOrigin.value(origin),
        release_after: Map.get(from_request, "release_after", 0),
        aws:
          AgentNameSettings.AWS.new(
            account_id: Map.get(from_request["aws"], "account_id", ""),
            role_name_patterns: Map.get(from_request["aws"], "role_name_patterns", "")
          )
      )
    else
      AgentNameSettings.new(
        assignment_origin: AssignmentOrigin.value(origin),
        release_after: Map.get(from_request, "release_after", 0)
      )
    end
  rescue
    e ->
      throw(
        ToTuple.user_error("invalid assignment_origin '#{from_request["assignment_origin"]}'")
      )
  end
end
