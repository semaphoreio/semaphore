defmodule Front.SelfHostedAgents.AgentType do
  alias InternalApi.SelfHosted.SelfHostedAgents.Stub, as: Stub

  alias InternalApi.SelfHosted.{
    CreateRequest,
    DeleteAgentTypeRequest,
    DescribeRequest,
    DisableAgentRequest,
    DisableAllAgentsRequest,
    ListAgentsRequest,
    ListRequest,
    ResetTokenRequest,
    UpdateRequest
  }

  require Logger

  defp name_settings(params) do
    InternalApi.SelfHosted.AgentNameSettings.new(
      assignment_origin:
        InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin.value(
          String.to_atom(params["agent_name_assignment_origin"])
        ),
      release_after: String.to_integer(params["agent_name_release_after"]),
      aws: name_settings_aws(params["agent_name_assignment_origin"], params)
    )
  end

  defp name_settings_aws("ASSIGNMENT_ORIGIN_AGENT", _params), do: nil

  defp name_settings_aws("ASSIGNMENT_ORIGIN_AWS_STS", params) do
    InternalApi.SelfHosted.AgentNameSettings.AWS.new(
      account_id: params["aws_account"],
      role_name_patterns: params["aws_role_patterns"]
    )
  end

  def create(org_id, name, requester_id, params) do
    Watchman.benchmark("self_hosted_agents.create.duration", fn ->
      {:ok, ch} = channel()

      req =
        CreateRequest.new(
          organization_id: org_id,
          name: name,
          requester_id: requester_id,
          agent_name_settings: name_settings(params)
        )

      case Stub.create(ch, req) do
        {:ok, res} ->
          {:ok, res.agent_type, res.agent_registration_token}

        {:error, error} ->
          Logger.error("Failed to create self hosted agent #{org_id}, #{name}")
          {:error, error}
      end
    end)
  end

  def update(org_id, name, requester_id, params) do
    Watchman.benchmark("self_hosted_agents.update.duration", fn ->
      {:ok, ch} = channel()

      req =
        UpdateRequest.new(
          organization_id: org_id,
          name: name,
          requester_id: requester_id,
          agent_type:
            InternalApi.SelfHosted.AgentType.new(
              organization_id: org_id,
              name: name,
              agent_name_settings: name_settings(params)
            )
        )

      case Stub.update(ch, req) do
        {:ok, res} ->
          {:ok, res.agent_type}

        {:error, error} ->
          Logger.error("Failed to update self hosted agent #{org_id}, #{name}: #{inspect(error)}")
          {:error, error}
      end
    end)
  end

  def list(org_id) do
    Watchman.benchmark("self_hosted_agents.list.duration", fn ->
      {:ok, ch} = channel()

      req = ListRequest.new(organization_id: org_id)

      case Stub.list(ch, req) do
        {:ok, res} -> {:ok, res.agent_types}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def list_agents(org_id, agent_type_name, cursor \\ "") do
    Watchman.benchmark("self_hosted_agents.list_agents.duration", fn ->
      {:ok, ch} = channel()

      req =
        ListAgentsRequest.new(
          organization_id: org_id,
          agent_type_name: agent_type_name,
          page_size: 200,
          cursor: cursor
        )

      case Stub.list_agents(ch, req) do
        {:ok, res} -> {:ok, res.agents, res.cursor}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def find(org_id, name) do
    Watchman.benchmark("self_hosted_agents.find.duration", fn ->
      {:ok, ch} = channel()

      req = DescribeRequest.new(organization_id: org_id, name: name)

      case Stub.describe(ch, req) do
        {:ok, res} -> {:ok, res.agent_type}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def delete(org_id, name) do
    Watchman.benchmark("self_hosted_agents.delete.duration", fn ->
      {:ok, ch} = channel()

      req = DeleteAgentTypeRequest.new(organization_id: org_id, name: name)

      case Stub.delete_agent_type(ch, req) do
        {:ok, _res} -> :ok
        {:error, error} -> {:error, error}
      end
    end)
  end

  def disable_agent(org_id, agent_type_name, agent_name) do
    Watchman.benchmark("self_hosted_agents.disable_agent.duration", fn ->
      {:ok, ch} = channel()

      req =
        DisableAgentRequest.new(
          organization_id: org_id,
          agent_type: agent_type_name,
          agent_name: agent_name
        )

      case Stub.disable_agent(ch, req) do
        {:ok, _res} -> :ok
        {:error, error} -> {:error, error}
      end
    end)
  end

  def reset_token(org_id, agent_type_name, disconnect_running_agents, requester_id) do
    Watchman.benchmark("self_hosted_agents.reset_token.duration", fn ->
      {:ok, ch} = channel()

      req =
        ResetTokenRequest.new(
          organization_id: org_id,
          agent_type: agent_type_name,
          disconnect_running_agents: disconnect_running_agents,
          requester_id: requester_id
        )

      case Stub.reset_token(ch, req) do
        {:ok, res} -> {:ok, res.token}
        {:error, error} -> {:error, error}
      end
    end)
  end

  def disable_all_agents(org_id, agent_type_name, only_idle) do
    Watchman.benchmark("self_hosted_agents.disable_all.duration", fn ->
      {:ok, ch} = channel()

      req =
        DisableAllAgentsRequest.new(
          organization_id: org_id,
          agent_type: agent_type_name,
          only_idle: only_idle
        )

      case Stub.disable_all_agents(ch, req) do
        {:ok, _res} -> :ok
        {:error, error} -> {:error, error}
      end
    end)
  end

  defp channel do
    endpoint = Application.fetch_env!(:front, :self_hosted_agents_grpc_endpoint)

    GRPC.Stub.connect(endpoint)
  end
end
