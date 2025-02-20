defmodule Gofer.Actions.CreateImpl do
  @moduledoc """
  Serves for creating seitch and targets models from given params.
  """
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Switch.Engine.SwitchSupervisor
  alias Util.ToTuple
  alias LogTee, as: LT

  def create_switch(switch_def, targets_defs) do
    id = UUID.uuid4()
    switch_def = Map.put(switch_def, "id", id)

    case SwitchSupervisor.start_switch_process(id, {switch_def, targets_defs}) do
      {:ok, _} ->
        {:ok, id}

      {:error, {:ppl_id_exists, ppl_id}} ->
        {:ok, switch} = SwitchQueries.get_by_ppl_id(ppl_id)
        {:ok, switch.id}

      {:error, message} ->
        {:error, message} |> LT.error("Create request failure")

      error ->
        error |> ToTuple.error() |> LT.error("Create request failure")
    end
  end

  # Functions for inserting into DB called from init of SwitchProcess

  def persist_switch_and_targets_def(switch_def, raw_targets_defs) do
    case validate_and_transform(switch_def, raw_targets_defs) do
      {:ok, targets_defs, _names} ->
        persist_switch_and_targets_def_(switch_def, targets_defs)

      error ->
        error
    end
  end

  defp validate_and_transform(switch_def, targets_defs) do
    targets_defs
    |> Enum.reduce_while({:ok, [], %{}}, fn raw_target_def, {:ok, targets, names} ->
      with {:ok, names} <- check_name_uniqueness(raw_target_def, names),
           {:ok, target_def} <- param_env_vars_validation(raw_target_def),
           {:ok, _deployment} <- check_deployment_target_exists(switch_def, raw_target_def) do
        {:cont, {:ok, targets ++ [target_def], names}}
      else
        {:error, e} -> {:halt, {:error, e}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp check_name_uniqueness(map, names, error_msg \\ nil)

  defp check_name_uniqueness(%{"name" => name}, names, error_msg) do
    {is_taken, names} =
      Map.get_and_update(names, name, fn current_value ->
        {current_value, true}
      end)

    case is_taken do
      nil ->
        {:ok, names}

      _val ->
        (error_msg || "There are at least two targets with same name: #{name}")
        |> ToTuple.error(:MALFORMED)
    end
  end

  defp check_name_uniqueness(map, _names, _error_msg),
    do: {:error, {:MALFORMED, "Missing 'name' property in #{inspect(map)}"}}

  defp param_env_vars_validation(target_def) do
    target_def
    |> Map.get("parameter_env_vars", [])
    |> Enum.reduce_while({:ok, %{}}, fn p_e_v, {:ok, res_map} ->
      case validate_param_env_var(res_map, p_e_v) do
        {:ok, new_res_map} -> {:cont, {:ok, new_res_map}}
        error -> {:halt, error}
      end
    end)
    |> update_target_def_if_ok(target_def)
  end

  defp validate_param_env_var(env_vars_map, env_var) do
    error_msg =
      "Parameter environment variable with name '#{env_var["name"]}'" <>
        " is defined at least two times."

    env_var
    |> check_name_uniqueness(env_vars_map, error_msg)
    |> optional_or_default(env_var)
    |> add_to_map(env_vars_map)
  end

  defp optional_or_default(error = {:error, _msg}, _env_var), do: error

  defp optional_or_default(_names, param = %{"required" => req, "default_value" => def})
       when req == false and def != "" do
    "Invalid parameter: '#{param["name"]}' - it can either be optional or have default value."
    |> ToTuple.error(:MALFORMED)
  end

  defp optional_or_default(_names, env_var), do: {:ok, env_var}

  defp add_to_map({:ok, env_var}, env_vars_map) do
    env_vars_map |> Map.put(env_var["name"], env_var) |> ToTuple.ok()
  end

  defp add_to_map(error = {:error, _msg}, _res_map), do: error

  defp update_target_def_if_ok({:ok, env_vars}, target_def),
    do: target_def |> Map.put("parameter_env_vars", env_vars) |> ToTuple.ok()

  defp update_target_def_if_ok(error, _target_def), do: error

  defp check_deployment_target_exists(_switch_def, %{"deployment_target" => nil}), do: {:ok, nil}
  defp check_deployment_target_exists(_switch_def, %{"deployment_target" => ""}), do: {:ok, nil}

  defp check_deployment_target_exists(switch_def, raw_target_def) do
    project_id = Map.get(switch_def, "project_id", "")
    target_name = Map.get(raw_target_def, "deployment_target", "")

    if is_binary(target_name) and target_name != "" do
      lookup_result = DeploymentQueries.find_by_project_and_name(project_id, target_name)
      error_msg = ~s(Invalid parameter: '#{target_name}' deployment target not found)

      case lookup_result do
        {:ok, deployment} -> {:ok, deployment}
        {:error, :not_found} -> {:error, {:MALFORMED, error_msg}}
      end
    else
      {:ok, nil}
    end
  end

  defp persist_switch_and_targets_def_(switch_def, targets_defs) do
    with {:ok, switch} <- insert_switch(switch_def),
         {:ok, _targets} <- insert_targets(targets_defs, switch),
         do: {:ok, "Switch and targets created successfully."}
  end

  defp insert_switch(switch_def) do
    case SwitchQueries.insert(switch_def) do
      {:ok, switch} -> {:ok, switch}
      {:error, {:switch_id_exists, id}} -> SwitchQueries.get_by_id(id)
      {:error, e} -> {:error, e}
      error -> {:error, error}
    end
  end

  defp insert_targets(targets_defs, switch) do
    Enum.reduce_while(targets_defs, {:ok, ""}, fn target_def, _acc ->
      case TargetQueries.insert(target_def, switch) do
        {:ok, _target} -> {:cont, {:ok, "Target insert successfull"}}
        {:error, {:target_exists, _e}} -> {:cont, {:ok, "Target insert successfull"}}
        {:error, e} -> {:halt, {:error, e}}
        error -> {:halt, {:error, error}}
      end
    end)
  end
end
