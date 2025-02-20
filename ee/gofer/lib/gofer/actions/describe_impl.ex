defmodule Gofer.Actions.DescribeImpl do
  @moduledoc """
  Collects functions needed for describing switch, targets and trigger events.
  """

  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.TargetTrigger.Model.TargetTriggerQueries, as: TTQueries
  alias Util.ToTuple

  def describe_switch(switch_id, triggers_no, requester_id) do
    with {:ok, switch} <- SwitchQueries.get_by_id(switch_id),
         {:ok, targets} <- TargetQueries.get_targets_description_for_switch(switch_id),
         {:ok, dt_descriptions} <- form_deployment_descriptions(switch, targets, requester_id),
         {:ok, targets_desc} <-
           transform_and_add_targets_triggers(
             switch_id,
             targets,
             dt_descriptions,
             triggers_no
           ),
         {:ok, description} <- form_description(switch, targets_desc) do
      {:ok, description}
    else
      {:error, msg = "Switch with id " <> _rest} -> {:ok, {:NOT_FOUND, msg}}
      resp = {:error, _e} -> resp
      error -> {:error, error}
    end
  end

  defp transform_and_add_targets_triggers(switch_id, targets, dt_descriptions, triggers_no) do
    targets
    |> Enum.reduce_while({:ok, []}, fn raw_target, {:ok, results} ->
      with {:ok, target} <- transform_target(raw_target),
           {:ok, target_desc} <- add_trigger_info_to_target(switch_id, target, triggers_no) do
        target_desc = maybe_enrich_with_deployment(target_desc, dt_descriptions)
        acc_results = if is_nil(target_desc), do: results, else: results ++ [target_desc]
        {:cont, {:ok, acc_results}}
      else
        {:error, e} ->
          {:halt, {:error, e}}

        error ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp transform_target(raw_target) do
    p_e_v =
      raw_target.parameter_env_vars
      |> Map.values()
      |> to_atom_keys()

    raw_target |> Map.put(:parameter_env_vars, p_e_v) |> ToTuple.ok()
  end

  defp add_trigger_info_to_target(switch_id, target, triggers_no) do
    with {:ok, target_triggers} <-
           TTQueries.get_last_n_triggers_for_target(switch_id, target.name, triggers_no),
         target_desc <- Map.put(target, :trigger_events, target_triggers) do
      {:ok, target_desc}
    else
      resp = {:error, _e} -> resp
      error -> {:error, error}
    end
  end

  defp maybe_enrich_with_deployment(target_description, dt_descriptions) do
    target_name = target_description.deployment_target
    dt_description = Map.get(dt_descriptions, target_name, not_found_dt_description(target_name))

    if is_nil(target_name) or target_name == "" do
      target_description
    else
      Map.put(target_description, :dt_description, dt_description)
    end
  end

  defp form_deployment_descriptions(switch, targets, requester_id) do
    deployments =
      if any_target_has_deployment_target?(targets),
        do: DeploymentQueries.list_by_project(switch.project_id),
        else: []

    {:ok, Enum.into(deployments, %{}, &form_deployment_description(switch, &1, requester_id))}
  end

  defp any_target_has_deployment_target?(targets) do
    targets
    |> Stream.filter(& &1.deployment_target)
    |> Stream.map(& &1.deployment_target)
    |> Enum.any?(&(String.length(&1) > 0))
  end

  defp form_deployment_description(switch, deployment, requester_id) do
    %Gofer.Deployment.Model.Deployment{id: id, name: name} = deployment

    guardian_result =
      Gofer.Deployment.Guardian.verify(deployment, switch, requester_id, cached?: true)

    {name, %{target_id: id, target_name: name, access: form_access(guardian_result)}}
  end

  defp form_access({:ok, metadata}) do
    LogTee.debug(metadata, "Granting access to deployment target")
    message = ~s(You can deploy to %{deployment_target})
    %{allowed: true, reason: :NO_REASON, message: message}
  end

  defp form_access({:error, {:SYNCING_TARGET, meta}}) do
    LogTee.debug(meta, "Deployment target is syncing while asking for access")
    message = ~s(%{deployment_target} is syncing, please wait)
    %{allowed: false, reason: :SYNCING_TARGET, message: message}
  end

  defp form_access({:error, {:CORRUPTED_TARGET, meta}}) do
    LogTee.debug(meta, "Corrupted deployment target blocks deployment access")
    message = ~s(%{deployment_target} is corrupted and cannot be used to promote)
    %{allowed: false, reason: :CORRUPTED_TARGET, message: message}
  end

  defp form_access({:error, {:CORDONED_TARGET, meta}}) do
    LogTee.debug(meta, "Cordoned deployment target blocks deployment access")
    message = ~s(%{deployment_target} is cordoned and cannot be used to promote)
    %{allowed: false, reason: :CORDONED_TARGET, message: message}
  end

  defp form_access({:error, {:BANNED_OBJECT, meta}}) do
    LogTee.debug(meta, "Forbidden object passed to deployment target")
    object = ~s(#{meta[:git_ref_type]} "#{meta[:label]}")
    message = ~s(Deployments from #{object} to %{deployment_target} are forbidden)
    %{allowed: false, reason: :BANNED_OBJECT, message: message}
  end

  defp form_access({:error, {:BANNED_SUBJECT, meta}}) do
    LogTee.debug(meta, "Forbidden subject passed to deployment target")
    message = ~s(You don't have rights to deploy to %{deployment_target})
    %{allowed: false, reason: :BANNED_SUBJECT, message: message}
  end

  defp not_found_dt_description(target_name) do
    message = ~s(%{deployment_target} was deleted, promotions are blocked for security reasons)
    access = %{allowed: false, reason: :CORRUPTED_TARGET, message: message}
    %{target_id: "", target_name: target_name, access: access}
  end

  defp form_description(switch, targets_desc) do
    %{
      switch_id: switch.id,
      ppl_id: switch.ppl_id,
      pipeline_done: switch.ppl_done,
      pipeline_result: switch.ppl_result || "",
      pipeline_result_reason: switch.ppl_result_reason || "",
      targets: targets_desc
    }
    |> ToTuple.ok()
  end

  defp to_atom_keys(map) when is_map(map) do
    map |> Enum.into(%{}, fn {k, v} -> {k |> String.to_atom(), to_atom_keys(v)} end)
  end

  defp to_atom_keys(list) when is_list(list) do
    list |> Enum.map(fn v -> to_atom_keys(v) end)
  end

  defp to_atom_keys(term), do: term
end
