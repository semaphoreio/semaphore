defmodule PipelinesAPI.SelfHostedHubClient.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from self-hosted-hub service and transforming it
  from protobuf messages into more suitable format for HTTP communication with API clients
  """

  alias InternalApi.SelfHosted.Agent.State
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
    {:ok, serialize(response.agent_type, nil)}
  end

  def process_describe_response(error), do: error

  def process_describe_agent_response({:ok, response}) do
    {:ok, serialize_agent(response.agent)}
  end

  def process_describe_agent_response(error), do: error

  def process_list_response({:ok, response}) do
    agent_types = Enum.map(response.agent_types, fn agent_type -> serialize(agent_type, nil) end)
    {:ok, %{agent_types: agent_types}}
  end

  def process_list_response(error), do: error

  def process_list_agents_response({:ok, response}) do
    agents = Enum.map(response.agents, fn agent -> serialize_agent(agent) end)
    {:ok, %{agents: agents, cursor: response.cursor}}
  end

  def process_list_agents_response(error), do: error

  defp serialize(agent_type, registration_token) do
    %{
      metadata: metadata(agent_type),
      spec: spec(agent_type),
      status: status(agent_type, registration_token)
    }
  end

  defp serialize_agent(agent) do
    %{
      metadata: agent_metadata(agent),
      status: agent_status(agent)
    }
  end

  defp metadata(agent_type) do
    %{
      name: agent_type.name,
      create_time: timestamp_to_datetime_string(agent_type.created_at),
      update_time: timestamp_to_datetime_string(agent_type.updated_at)
    }
  end

  defp spec(agent_type) do
    settings = agent_type.agent_name_settings

    %{
      agent_name_settings: %{
        assignment_origin: state_to_string(settings.assignment_origin),
        release_after: settings.release_after,
        aws: settings.aws
      }
    }
  end

  defp agent_metadata(agent) do
    metadata = %{
      name: agent.name,
      type: agent.type_name,
      connected_at: timestamp_to_datetime_string(agent.connected_at),
      version: agent.version,
      os: agent.os,
      arch: agent.arch,
      hostname: agent.hostname,
      ip_address: agent.ip_address,
      pid: agent.pid
    }

    if agent.disabled_at != nil do
      metadata |> Map.put(:disabled_at, timestamp_to_datetime_string(agent.disabled_at))
    else
      metadata
    end
  end

  defp agent_status(agent) do
    %{
      state: state_to_string(agent.state)
    }
  end

  defp status(agent_type, nil), do: %{total_agent_count: agent_type.total_agent_count}

  defp status(agent_type, registration_token) do
    %{
      total_agent_count: agent_type.total_agent_count,
      registration_token: registration_token
    }
  end

  def timestamp_to_datetime_string(%{nanos: 0, seconds: 0}), do: ""
  def timestamp_to_datetime_string(%{nanos: _nanos, seconds: seconds}), do: seconds

  def state_to_string(value) when is_atom(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def state_to_string(value) when is_integer(value) do
    value |> State.key() |> Atom.to_string() |> String.downcase()
  end

  def assignment_origin_to_string(value) when is_atom(value) do
    value |> Atom.to_string() |> String.downcase()
  end

  def assignment_origin_to_string(value) when is_integer(value) do
    value |> AssignmentOrigin.key() |> Atom.to_string() |> String.downcase()
  end
end
