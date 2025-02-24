defmodule Front.ActivityMonitor.AgentStats do
  alias Front.ActivityMonitor.Repo
  alias InternalApi.ServerFarm.Job.Job

  alias __MODULE__

  defstruct [
    :agent_types,
    :self_hosted_agent_types,
    :max_parallelism,
    :max_agents
  ]

  @type t :: %AgentStats{
          agent_types: [agent_type()],
          self_hosted_agent_types: [agent_type()],
          max_parallelism: integer(),
          max_agents: integer()
        }

  @type agent_type :: %{
          name: String.t(),
          occupied_count: integer(),
          waiting_count: integer(),
          total_count: integer()
        }

  @type activity :: %{
          waiting: integer(),
          occupied: integer()
        }

  @type activity_summary :: %{
          required(machine_type :: String.t()) => activity
        }

  @spec load(String.t()) :: t()
  def load(org_id) do
    agent_types =
      FeatureProvider.list_machines(param: org_id)
      |> case do
        {:ok, machines} -> Enum.map(machines, &build_agent_type/1)
        _ -> []
      end

    self_hosted_agent_types = load_self_hosted_agent_types(org_id)
    max_parallelism = load_max_parallelism(org_id)
    max_agents = FeatureProvider.feature_quota(:self_hosted_agents, param: org_id)

    %AgentStats{
      agent_types: agent_types,
      self_hosted_agent_types: self_hosted_agent_types,
      max_parallelism: max_parallelism,
      max_agents: max_agents
    }
  end

  @spec load_activity(t(), Repo.Data.t()) :: t()
  def load_activity(agents, data) do
    debug_jobs = Enum.map(data.active_debug_sessions, fn item -> item.debug_session end)
    all_jobs = data.active_jobs ++ debug_jobs

    job_activity = job_summary(all_jobs)

    agent_types =
      agents.agent_types
      |> Enum.map(fn agent_type ->
        job_activity
        |> Map.get(agent_type.name)
        |> case do
          nil ->
            agent_type

          %{occupied: occupied_count, waiting: waiting_count} ->
            %{agent_type | occupied_count: occupied_count, waiting_count: waiting_count}
        end
      end)

    self_hosted_agent_types =
      agents.self_hosted_agent_types
      |> Enum.map(fn agent_type ->
        job_activity
        |> Map.get(agent_type.name)
        |> case do
          nil ->
            agent_type

          %{occupied: occupied_count, waiting: waiting_count} ->
            %{agent_type | occupied_count: occupied_count, waiting_count: waiting_count}
        end
      end)

    %{agents | agent_types: agent_types, self_hosted_agent_types: self_hosted_agent_types}
  end

  @spec build_agent_type(FeatureProvider.Machine.t()) :: agent_type()
  defp build_agent_type(machine = %FeatureProvider.Machine{}) do
    %{
      name: machine.type,
      occupied_count: 0,
      waiting_count: 0,
      total_count: FeatureProvider.Machine.quota(machine)
    }
  end

  @spec build_self_hosted_agent_type(InternalApi.SelfHosted.AgentType.t()) :: agent_type()
  defp build_self_hosted_agent_type(type = %InternalApi.SelfHosted.AgentType{}) do
    %{
      name: type.name,
      occupied_count: 0,
      waiting_count: 0,
      total_count: type.total_agent_count
    }
  end

  @spec load_max_parallelism(String.t()) :: integer()
  def load_max_parallelism(org_id) do
    FeatureProvider.feature_quota(:max_paralellism_in_org, param: org_id)
  end

  def load_self_hosted_agent_types(org_id) do
    if FeatureProvider.feature_enabled?(:self_hosted_agents, param: org_id) do
      Front.SelfHostedAgents.AgentType.list(org_id)
      |> case do
        {:ok, types} -> Enum.map(types, &build_self_hosted_agent_type/1)
        _ -> []
      end
    else
      []
    end
  end

  @spec job_summary([Job.t()]) :: activity_summary
  defp job_summary(all_jobs) do
    all_jobs
    |> Enum.reduce(%{}, fn job, machine_counts ->
      machine_counts
      |> Map.update(job.machine_type, zero_state(job), fn state ->
        cond do
          job.state == :STARTED ->
            %{state | occupied: state.occupied + 1}

          job.state == :ENQUEUED ->
            %{state | waiting: state.waiting + 1}

          job.state == :SCHEDULED and job.self_hosted ->
            %{state | waiting: state.waiting + 1}

          true ->
            state
        end
      end)
    end)
  end

  defp zero_state(job) do
    cond do
      job.state == :STARTED ->
        %{waiting: 0, occupied: 1}

      job.state == :ENQUEUED ->
        %{waiting: 1, occupied: 0}

      job.state == :SCHEDULED and job.self_hosted ->
        %{waiting: 1, occupied: 0}

      true ->
        %{waiting: 0, occupied: 0}
    end
  end
end
