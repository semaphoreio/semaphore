defmodule Front.Models.Billing.PlanSwitch do
  @moduledoc """
  This module provides functions to switch between different billing plans.
  """
  alias Front.Models.Billing

  @type plan_type ::
          :unknown | :startup_cloud | :startup_hybrid | :free | :open_source | :scaleup

  @type validation_error :: [{key :: atom(), message :: String.t()}]

  @doc """
  Maps the current plan to a plan type.
  """
  @spec current_plan_type(Billing.Plan.t()) :: plan_type()
  def current_plan_type(plan) do
    plan.slug
    |> case do
      "paid" -> :startup_cloud
      "startup" -> :startup_cloud
      "startup_hybrid" -> :startup_hybrid
      "free" -> :free
      "open_source" -> :open_source
      "scaleup" -> :scaleup
      "scaleup_hybrid" -> :scaleup
      _ -> :unknown
    end
  end

  @spec plan_type_to_slug(plan_type() | String.t()) :: String.t()
  def plan_type_to_slug(plan_type) when is_atom(plan_type), do: plan_type_to_slug("#{plan_type}")

  def plan_type_to_slug(plan_type) do
    case plan_type do
      "startup_cloud" -> "paid"
      "startup_hybrid" -> "startup_hybrid"
      "free" -> "free"
      _ -> ""
    end
  end

  @spec validate_plan_change(
          org_id :: String.t(),
          plan_type()
        ) ::
          :ok | {:error, validation_error()}
  def validate_plan_change(org_id, plan_type) do
    with :ok <- can_switch_plan?(org_id, plan_type: plan_type),
         {:ok, available_plan} <- get_plan(org_id, plan_type),
         :ok <- users_within_limit(org_id, available_plan),
         :ok <- agents_within_limit(org_id, available_plan) do
      :ok
    else
      {:error, validation_errors} when is_list(validation_errors) -> {:error, validation_errors}
      _ -> {:error, [{:plan, "Can't switch to this plan."}]}
    end
  end

  @spec list_plans(org_id :: String.t()) :: [Billing.PlanSwitch.AvailablePlan.t()]
  def list_plans(org_id) do
    can_switch_plan?(org_id)
    |> case do
      :ok -> available_plans()
      {:error, _} -> []
    end
  end

  @spec get_plan(org_id :: String.t(), plan_type()) ::
          {:ok, Billing.PlanSwitch.AvailablePlan.t()} | {:error, validation_error()}
  defp get_plan(org_id, plan_type) do
    list_plans(org_id)
    |> Enum.find(&(&1.type == plan_type))
    |> case do
      nil -> {:error, [plan: "Plan not found."]}
      available_plan -> {:ok, available_plan}
    end
  end

  @spec can_switch_plan?(org_id :: String.t(), opts :: Keyword.t()) ::
          :ok | {:error, validation_error()}
  defp can_switch_plan?(org_id, opts \\ []) do
    plan_slug =
      opts
      |> Keyword.get(:plan_slug, "")

    Front.Clients.Billing.can_upgrade_plan(%{org_id: org_id, plan_slug: plan_slug})
    |> case do
      {:ok, %{allowed: true}} ->
        :ok

      {:ok, %{allowed: false, errors: errors}} ->
        validation_errors = errors |> Enum.map(&{:plan, &1})
        {:error, validation_errors}

      {:error, error} ->
        require Logger
        Logger.error(inspect(error))
        {:error, [generic: "Failed to check plan upgrade."]}
    end
  end

  @spec users_within_limit(org_id :: String.t(), Billing.PlanSwitch.AvailablePlan.t()) ::
          :ok | {:error, validation_error()}
  defp users_within_limit(_, available_plan) when available_plan.features.max_users == -1,
    do: :ok

  defp users_within_limit(org_id, available_plan) do
    max_users = available_plan.features.max_users

    Front.RBAC.Members.list_org_members(org_id)
    |> case do
      {:ok, {users, _pages}} ->
        approx_user_count = length(users)

        if approx_user_count <= max_users do
          :ok
        else
          {:error, [users: "Users limit exceeded."]}
        end

      {:error, _} ->
        {:error, [generic: "Failed to fetch users."]}
    end
  end

  @spec agents_within_limit(org_id :: String.t(), Billing.PlanSwitch.AvailablePlan.t()) ::
          :ok | {:error, validation_error()}
  defp agents_within_limit(_, available_plan)
       when available_plan.features.max_self_hosted_agents == -1,
       do: :ok

  defp agents_within_limit(org_id, available_plan) do
    max_agents = available_plan.features.max_self_hosted_agents

    Front.SelfHostedAgents.AgentType.list_agents(org_id, "")
    |> case do
      {:ok, agents, _} ->
        if length(agents) <= max_agents do
          :ok
        else
          {:error, [agents: "Agents limit exceeded."]}
        end

      {:error, _} ->
        {:error, [generic: "Failed to fetch agents."]}
    end
  end

  @spec available_plans() :: [Billing.PlanSwitch.AvailablePlan.t()]
  defp available_plans do
    [
      Billing.PlanSwitch.AvailablePlan.new(
        name: "Startup - Cloud",
        type: :startup_cloud,
        description: "Pay only for used machine time, no seat costs.",
        features: [
          parallelism: -1,
          max_users: -1,
          max_self_hosted_agents: 0,
          cloud_minutes: -1,
          seat_cost: 0,
          large_resource_types: true,
          priority_support: true
        ]
      ),
      Billing.PlanSwitch.AvailablePlan.new(
        name: "Startup - Hybrid",
        type: :startup_hybrid,
        description: "Run jobs on your own infrastructure.",
        features: [
          parallelism: -1,
          max_users: -1,
          max_self_hosted_agents: -1,
          cloud_minutes: -1,
          seat_cost: 9,
          large_resource_types: true,
          priority_support: true
        ]
      ),
      Billing.PlanSwitch.AvailablePlan.new(
        name: "Free",
        type: :free,
        description: "Good for smaller teams self-end occasional use.",
        features: [
          parallelism: 40,
          max_users: 5,
          max_self_hosted_agents: 5,
          cloud_minutes: 7000,
          seat_cost: 0,
          large_resource_types: false,
          priority_support: false
        ]
      )
    ]
  end
end
