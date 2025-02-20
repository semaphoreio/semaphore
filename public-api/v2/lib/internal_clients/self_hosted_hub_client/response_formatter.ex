defmodule InternalClients.SelfHostedHub.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from self-hosted-hub service and transforming it
  from protobuf messages into more suitable format for HTTP communication with API clients
  """

  alias InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin

  def process_create_response({:ok, response}) do
    {:ok, serialize(response.agent_type, response.agent_registration_token)}
  end

  def process_create_response(error), do: error

  def process_update_response({:ok, response}) do
    {:ok, serialize(response.agent_type, nil)}
  end

  def process_update_response(error), do: error

  def process_describe_response({:ok, response}) do
    require Logger
    Logger.info("response: #{inspect(response)}")
    {:ok, serialize(response.agent_type, nil)}
  end

  def process_describe_response(error), do: error

  def process_describe_agent_response({:ok, response}) do
    {:ok, serialize_agent(response.agent)}
  end

  def process_describe_agent_response(error), do: error

  def process_list_response({:ok, response}) do
    agent_types = Enum.map(response.agent_types, fn agent_type -> serialize(agent_type, nil) end)
    {:ok, %{entries: agent_types, next_page_token: response.next_page_cursor}}
  end

  def process_list_response(error), do: error

  def process_list_agents_response({:ok, response}) do
    agents = Enum.map(response.agents, fn agent -> serialize_agent(agent) end)
    {:ok, %{entries: agents, next_page_token: response.cursor}}
  end

  def process_list_agents_response(error), do: error

  def process_delete_response({:ok, _response}),
    do: {:ok, %{message: "Agent type deleted successfully"}}

  def process_delete_response(error), do: error

  def process_disable_all_response({:ok, _response}),
    do: {:ok, %{message: "Agents for agent type disabled successfully"}}

  def process_disable_all_response(error), do: error

  defp serialize(agent_type, registration_token) do
    %{
      apiVersion: "v2",
      kind: "SelfHostedAgentType",
      metadata: metadata(agent_type, registration_token),
      spec: spec(agent_type)
    }
  end

  defp serialize_agent(agent) do
    %{
      apiVersion: "v2",
      kind: "SelfHostedAgent",
      metadata: agent_metadata(agent)
    }
  end

  defp metadata(agent_type, reg_token) do
    %{
      name: agent_type.name,
      created_at: PublicAPI.Util.Timestamps.to_timestamp(agent_type.created_at),
      updated_at: PublicAPI.Util.Timestamps.to_timestamp(agent_type.updated_at),
      org_id: agent_type.organization_id,
      status: status(agent_type, reg_token)
    }
  end

  defp spec(agent_type) do
    %{
      agent_name_settings: agent_name_settings(agent_type.agent_name_settings),
      name: agent_type.name
    }
  end

  defp agent_name_settings(nil),
    do: %{assignment_origin: "ASSIGNMENT_ORIGIN_AGENT", release_after: 0}

  defp agent_name_settings(settings) do
    %{
      assignment_origin:
        Map.get(settings, :assignment_origin, :ASSIGNMENT_ORIGIN_UNSPECIFIED) |> Atom.to_string(),
      release_after: settings.release_after,
      aws: aws_from_pb(settings.aws)
    }
  end

  defp aws_from_pb(nil), do: nil

  defp aws_from_pb(aws = %InternalApi.SelfHosted.AgentNameSettings.AWS{}) do
    %{
      account_id: aws.account_id,
      role_name_patterns: aws.role_name_patterns
    }
  end

  defp agent_metadata(agent) do
    metadata = %{
      name: agent.name,
      org_id: agent.organization_id,
      type: agent.type_name,
      connected_at: PublicAPI.Util.Timestamps.to_timestamp(agent.connected_at),
      version: agent.version,
      os: agent.os,
      arch: agent.arch,
      hostname: agent.hostname,
      ip_address: agent.ip_address,
      status: agent.state |> Atom.to_string(),
      pid: agent.pid
    }

    if agent.disabled_at != nil do
      metadata |> Map.put(:disabled_at, PublicAPI.Util.Timestamps.to_timestamp(agent.disabled_at))
    else
      metadata
    end
  end

  defp status(agent_type, nil), do: %{total_agent_count: agent_type.total_agent_count}

  defp status(agent_type, registration_token) do
    %{
      total_agent_count: agent_type.total_agent_count,
      registration_token: registration_token
    }
  end

  def assignment_origin_to_string(value) when is_atom(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def assignment_origin_to_string(value) when is_integer(value) do
    value |> AssignmentOrigin.key() |> Atom.to_string() |> String.downcase()
  end
end
