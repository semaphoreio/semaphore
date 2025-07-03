defmodule Gofer.Actions.TriggerImpl do
  @moduledoc """
  Collects actions for triggering target on users manual request.
  """
  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor
  alias Util.ToTuple
  alias LogTee, as: LT

  alias Gofer.DeploymentTrigger.Engine.Supervisor, as: DeploymentTriggerSupervisor
  alias Gofer.DeploymentTrigger.Model.DeploymentTriggerQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.Deployment.Guardian

  def trigger(params) do
    case trigger_target(params) do
      {:ok, _} ->
        {:ok, {:OK, "Target trigger request recorded."}}

      {:error, {:request_token_exists, _request_token}} ->
        {:ok, {:OK, "Target trigger request recorded."}}

      {:error, {:NOT_FOUND, message}} ->
        {:ok, {:NOT_FOUND, message}}

      {:error, {:REFUSED, message}} ->
        {:ok, {:REFUSED, message}}

      {:error, message} ->
        {:error, message} |> LT.error("Trigger request failure")

      error ->
        error |> ToTuple.error() |> LT.error("Trigger request failure")
    end
  end

  defp trigger_target(request) do
    with {:ok, switch} <- SwitchQueries.get_by_id(request.switch_id),
         {:ok, target} <-
           TargetQueries.get_by_id_and_name(request.switch_id, request.target_name),
         :ok <- override_if_ppl_not_passed?(switch.ppl_result, request.override) do
      start_trigger(switch, target, request)
    else
      resp = {:error, {:REFUSED, _message}} -> resp
      {:error, msg = "Switch with id " <> _rest} -> {:error, {:NOT_FOUND, msg}}
      {:error, msg = "Target for switch: " <> _rest} -> {:error, {:NOT_FOUND, msg}}
      error -> error
    end
  end

  defp override_if_ppl_not_passed?("passed", _override), do: :ok
  defp override_if_ppl_not_passed?(_result, true), do: :ok

  defp override_if_ppl_not_passed?(_result, _override),
    do:
      {:error,
       {:REFUSED, "Triggering target when pipeline is not passed requires override confirmation."}}

  defp form_env_vars_for_target(target, request) do
    request.env_variables
    |> Enum.reduce_while({:ok, [], target.parameter_env_vars}, fn env_var,
                                                                  {:ok, list, env_vars_map} ->
      case valid_value(env_vars_map, env_var.name, env_var.value) do
        {:ok, reduced_map} ->
          {:cont,
           {:ok, list ++ [%{"name" => env_var.name, "value" => env_var.value}], reduced_map}}

        error ->
          {:halt, error}
      end
    end)
    |> add_defaults_and_check_required()
    |> form_env_vars_for_target_(target.name)
  end

  defp valid_value(env_vars_map, name, value) do
    env_vars_map
    |> Map.get(
      name,
      {:error, "Parameter '#{name}' is not defined in promotion's yml definition."}
    )
    |> valid_value_(value)
    |> remove_env_var_from_map(env_vars_map, name)
  end

  defp valid_value_(error = {:error, _msg}, _value), do: error
  defp valid_value_(%{"options" => []}, _value), do: true

  defp valid_value_(df = %{"options" => options, "name" => name}, value) do
    options
    |> add_default_value(df["default_value"])
    |> Enum.member?(value)
    |> if do
      true
    else
      "Value '#{value}' of parameter '#{name}' is not one of predefined options."
      |> ToTuple.error()
    end
  end

  defp add_default_value(list, ""), do: list
  defp add_default_value(list, value), do: list ++ [value]

  defp remove_env_var_from_map(error = {:error, _msg}, _map, _name), do: error

  defp remove_env_var_from_map(true, env_vars_map, name) do
    env_vars_map |> Map.delete(name) |> ToTuple.ok()
  end

  defp add_defaults_and_check_required({:ok, env_vars, not_used_env_vars}) do
    not_used_env_vars
    |> Enum.reduce_while({:ok, env_vars}, fn {name, ev_def}, {:ok, result_list} ->
      if is_binary(ev_def["default_value"]) and ev_def["default_value"] != "" do
        {:cont, {:ok, result_list ++ [%{name: name, value: ev_def["default_value"]}]}}
      else
        is_required?(ev_def, result_list)
      end
    end)
  end

  defp add_defaults_and_check_required(error), do: error

  defp is_required?(%{"required" => false}, list), do: {:cont, {:ok, list}}

  defp is_required?(%{"required" => true, "name" => name}, _list),
    do: {:halt, {:error, "Missing value for required parameter '#{name}'."}}

  defp form_env_vars_for_target_({:ok, env_vars}, target_name) do
    %{} |> Map.put(target_name, env_vars) |> ToTuple.ok()
  end

  defp form_env_vars_for_target_(error, _target_name), do: error

  defp form_trigger_params(request, env_vars) do
    %{
      "id" => UUID.uuid4(),
      "switch_id" => request.switch_id,
      "request_token" => request.request_token,
      "target_names" => [request.target_name],
      "triggered_by" => request.triggered_by,
      "triggered_at" => DateTime.utc_now(),
      "auto_triggered" => false,
      "override" => request.override,
      "env_vars_for_target" => env_vars,
      "processed" => false
    }
    |> ToTuple.ok()
  end

  defp start_trigger(_switch, target = %{deployment_target: nil}, request) do
    with {:ok, env_vars} <- form_env_vars_for_target(target, request),
         {:ok, params} <- form_trigger_params(request, env_vars),
         id <- Map.get(params, "id") do
      SwitchTriggerSupervisor.start_switch_trigger_process(id, params)
    end
  end

  defp start_trigger(switch, target, request) do
    metadata = [project_id: switch.project_id, deployment_name: target.deployment_target]
    [project_id: project_id, deployment_name: dpl_name] = metadata

    with {:ok, deployment} <- DeploymentQueries.find_by_project_and_name(project_id, dpl_name),
         {:ok, metadata} <- Guardian.verify(deployment, switch, request.triggered_by),
         {:ok, env_vars} <- form_env_vars_for_target(target, request),
         {:ok, params} <- form_trigger_params(request, env_vars),
         {:ok, trigger} <- DeploymentTriggerQueries.create(switch, deployment, params) do
      LT.debug(metadata, "Triggered promotion through deployment target")
      DeploymentTriggerSupervisor.start_worker(trigger)
    else
      {:error, _reason} = error ->
        handle_deployment_trigger_error(error, metadata) |> LT.info("DT trigger failed")
    end
  end

  defp handle_deployment_trigger_error({:error, :not_found}, metadata),
    do: {:error, {:NOT_FOUND, error_message("deployment target not found", metadata)}}

  defp handle_deployment_trigger_error({:error, {:SYNCING_TARGET, _meta}}, metadata),
    do: {:error, {:REFUSED, error_message("deployment target is syncing", metadata)}}

  defp handle_deployment_trigger_error({:error, {:CORRUPTED_TARGET, _meta}}, metadata),
    do: {:error, {:REFUSED, error_message("deployment target is corrupted", metadata)}}

  defp handle_deployment_trigger_error({:error, {:CORDONED_TARGET, _meta}}, metadata),
    do: {:error, {:REFUSED, error_message("deployment target is cordoned", metadata)}}

  defp handle_deployment_trigger_error({:error, {:BANNED_SUBJECT, meta}}, metadata),
    do: {:error, {:REFUSED, error_message("subject not allowed", Keyword.merge(metadata, meta))}}

  defp handle_deployment_trigger_error({:error, {:BANNED_OBJECT, meta}}, metadata),
    do: {:error, {:REFUSED, error_message("object not allowed", Keyword.merge(metadata, meta))}}

  defp error_message(message, metadata) do
    full_message =
      "Triggering promotion with deployment target failed: #{message} (error ID: #{UUID.uuid4()})"

    LT.warn(metadata, full_message)
    full_message
  end
end
