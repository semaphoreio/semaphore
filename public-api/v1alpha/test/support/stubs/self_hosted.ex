defmodule Support.Stubs.SelfHostedAgent do
  alias Support.Stubs.{DB, Time}

  def init do
    DB.add_table(:self_hosted_agent_types, [
      :id,
      :org_id,
      :name,
      :requester_id,
      :created_at,
      :updated_at,
      :agent_name_settings
    ])

    DB.add_table(:self_hosted_agents, [
      :id,
      :org_id,
      :agent_type_name,
      :name,
      :state,
      :arch,
      :hostname,
      :ip_address,
      :pid,
      :user_agent,
      :version,
      :os,
      :connected_at,
      :disabled_at
    ])

    __MODULE__.Grpc.init()
  end

  def create(org_id, name, user_id, agent_name_settings \\ nil) do
    # This makes it easier to test
    now = 1_668_202_871

    settings =
      if agent_name_settings != nil,
        do: agent_name_settings,
        else:
          InternalApi.SelfHosted.AgentNameSettings.new(
            assignment_origin:
              InternalApi.SelfHosted.AgentNameSettings.AssignmentOrigin.value(
                :ASSIGNMENT_ORIGIN_AGENT
              ),
            release_after: 0
          )

    DB.insert(:self_hosted_agent_types, %{
      id: UUID.uuid4(),
      org_id: org_id,
      name: name,
      requester_id: user_id,
      created_at: now,
      updated_at: now,
      agent_name_settings: settings
    })
  end

  def update(org_id, name, agent_name_settings) do
    agent_type =
      list(org_id)
      |> Enum.find(fn a ->
        a.org_id == org_id && a.name == name
      end)
      |> Map.put(:agent_name_settings, agent_name_settings)

    DB.update(:self_hosted_agent_types, agent_type)
  end

  def list(org_id) do
    DB.find_all_by(:self_hosted_agent_types, :org_id, org_id)
  end

  def find(org_id, name) do
    list(org_id)
    |> Enum.find(fn a ->
      a.org_id == org_id && a.name == name
    end)
  end

  def find_agent(org_id, name) do
    DB.all(:self_hosted_agents)
    |> Enum.filter(fn i ->
      i.org_id == org_id && i.name == name
    end)
    |> List.first()
  end

  def add_agent(org_id, agent_type_name, name, state \\ :WAITING_FOR_JOB) do
    # This makes it easier to test
    now = 1_668_202_871

    DB.insert(:self_hosted_agents, %{
      id: UUID.uuid4(),
      org_id: org_id,
      agent_type_name: agent_type_name,
      name: name,
      arch: "x86_64",
      hostname: "boxbox",
      ip_address: "182.92.12.1",
      pid: 90,
      user_agent: "SemaphoreAgent/v1.3.1",
      state: InternalApi.SelfHosted.Agent.State.value(state),
      version: "v1.5.9",
      os: "Ubuntu 14.04.5 LTS",
      connected_at: now,
      disabled_at: nil
    })
  end

  def change_agent_state(agent_id, state) do
    agent =
      DB.find(:self_hosted_agents, agent_id)
      |> Map.put(:disabled_at, Time.now())
      |> Map.put(:state, state)

    DB.update(:self_hosted_agents, agent)
  end

  def add_agent_to_last_agent_type do
    agent_type = DB.all(:self_hosted_agent_types) |> List.last()

    add_agent(agent_type.org_id, agent_type.name, "sh-231312h324j123")
  end

  def list_agents(org_id, "") do
    DB.all(:self_hosted_agents) |> Enum.filter(fn i -> i.org_id == org_id end)
  end

  def list_agents(org_id, type_name) do
    DB.all(:self_hosted_agents)
    |> Enum.filter(fn i ->
      i.org_id == org_id && i.agent_type_name == type_name
    end)
  end

  defmodule Grpc do
    alias Support.Stubs.SelfHostedAgent, as: SH

    def init do
      GrpcMock.stub(SelfHostedMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(SelfHostedMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(SelfHostedMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(SelfHostedMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(SelfHostedMock, :describe_agent, &__MODULE__.describe_agent/2)
      GrpcMock.stub(SelfHostedMock, :list_agents, &__MODULE__.list_agents/2)
      GrpcMock.stub(SelfHostedMock, :delete_agent_type, &__MODULE__.delete_agent_type/2)
      GrpcMock.stub(SelfHostedMock, :disable_agent, &__MODULE__.disable_agent/2)
      GrpcMock.stub(SelfHostedMock, :reset_token, &__MODULE__.reset_token/2)
      GrpcMock.stub(SelfHostedMock, :disable_all_agents, &__MODULE__.disable_all_agents/2)
    end

    def create(req, _) do
      alias InternalApi.SelfHosted.CreateResponse

      if String.starts_with?(req.name, "s1-") do
        case SH.find(req.organization_id, req.name) do
          nil ->
            agent_type =
              SH.create(req.organization_id, req.name, req.requester_id, req.agent_name_settings)

            CreateResponse.new(
              agent_type: serialize(agent_type),
              agent_registration_token:
                "31162eb3befd59ed1f601044ce76529c31162eb3befd59ed1f601044ce76529c"
            )

          _ ->
            raise GRPC.RPCError,
              status: GRPC.Status.already_exists(),
              message: "The agent type with name '#{req.name}' already exists"
        end
      else
        raise GRPC.RPCError,
          status: GRPC.Status.invalid_argument(),
          message: "The agent type name '#{req.name}' is not allowed"
      end
    end

    def update(req, _) do
      alias InternalApi.SelfHosted.UpdateResponse

      case SH.find(req.organization_id, req.name) do
        nil ->
          raise GRPC.RPCError,
            status: GRPC.Status.not_found(),
            message: "The agent type with name '#{req.name}' does not exist"

        _ ->
          agent_type =
            SH.update(req.organization_id, req.name, req.agent_type.agent_name_settings)

          UpdateResponse.new(agent_type: serialize(agent_type))
      end
    end

    def describe(req, _) do
      case SH.find(req.organization_id, req.name) do
        nil ->
          raise GRPC.RPCError,
            status: GRPC.Status.not_found(),
            message: "The agent type '#{req.name}' was not found"

        agent_type ->
          InternalApi.SelfHosted.DescribeResponse.new(agent_type: serialize(agent_type))
      end
    end

    def describe_agent(req, _) do
      case SH.find_agent(req.organization_id, req.name) do
        nil ->
          raise GRPC.RPCError,
            status: GRPC.Status.not_found(),
            message: "The agent '#{req.name}' was not found"

        agent ->
          InternalApi.SelfHosted.DescribeAgentResponse.new(agent: serialize_agent(agent))
      end
    end

    def list(req, _) do
      agent_types = SH.list(req.organization_id)

      InternalApi.SelfHosted.ListResponse.new(
        agent_types: serialize_many(agent_types),
        total_pages: 1,
        page: 1
      )
    end

    def list_agents(req, _) do
      agents = SH.list_agents(req.organization_id, req.agent_type_name)

      InternalApi.SelfHosted.ListAgentsResponse.new(
        agents: serialize_agents(agents),
        total_pages: 1,
        page: 1
      )
    end

    def delete_agent_type(req, _) do
      case SH.find(req.organization_id, req.name) do
        nil ->
          raise GRPC.RPCError,
            status: GRPC.Status.not_found(),
            message: "The agent type '#{req.name}' was not found"

        _agent_type ->
          DB.delete(:self_hosted_agent_types, fn at ->
            at.name == req.name && at.org_id == req.organization_id
          end)

          InternalApi.SelfHosted.DeleteAgentTypeResponse.new()
      end
    end

    def disable_agent(req, _) do
      agent =
        DB.filter(:self_hosted_agents,
          org_id: req.organization_id,
          agent_type_name: req.agent_type,
          name: req.agent_name
        )
        |> List.first()
        |> Map.put(:disabled_at, Time.now())

      DB.update(:self_hosted_agents, agent)
      InternalApi.SelfHosted.DisableAgentResponse.new()
    end

    def reset_token(_, _) do
      InternalApi.SelfHosted.ResetTokenResponse.new(
        token: "31162eb3befd59ed1f601044ce76529c31162eb3befd59ed1f601044ce76529c"
      )
    end

    def disable_all_agents(req, _) do
      agents =
        if req.only_idle do
          DB.filter(:self_hosted_agents,
            org_id: req.organization_id,
            agent_type_name: req.agent_type,
            state: InternalApi.SelfHosted.Agent.State.value(:WAITING_FOR_JOB)
          )
        else
          DB.filter(:self_hosted_agents,
            org_id: req.organization_id,
            agent_type_name: req.agent_type
          )
        end

      agents
      |> Enum.map(fn x -> Map.put(x, :disabled_at, Time.now()) end)
      |> Enum.each(fn x -> DB.update(:self_hosted_agents, x) end)

      InternalApi.SelfHosted.DisableAllAgentsResponse.new()
    end

    defp serialize_many(agent_types) do
      Enum.map(agent_types, fn agent_type -> serialize(agent_type) end)
    end

    defp serialize(agent_type) do
      alias InternalApi.SelfHosted.AgentType

      AgentType.new(
        organization_id: agent_type.org_id,
        name: agent_type.name,
        total_agent_count: length(SH.list_agents(agent_type.org_id, agent_type.name)),
        requester_id: agent_type.requester_id,
        created_at: Google.Protobuf.Timestamp.new(seconds: agent_type.created_at),
        updated_at: Google.Protobuf.Timestamp.new(seconds: agent_type.updated_at),
        agent_name_settings: agent_type.agent_name_settings
      )
    end

    defp serialize_agents(agents) do
      Enum.map(agents, fn a -> serialize_agent(a) end)
    end

    defp serialize_agent(agent) do
      InternalApi.SelfHosted.Agent.new(
        name: agent.name,
        version: agent.version,
        os: agent.os,
        arch: agent.arch,
        hostname: agent.hostname,
        ip_address: agent.ip_address,
        pid: agent.pid,
        user_agent: agent.user_agent,
        connected_at: Google.Protobuf.Timestamp.new(seconds: agent.connected_at),
        state: agent.state,
        type_name: agent.agent_type_name
      )
    end
  end
end
