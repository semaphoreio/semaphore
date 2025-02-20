defmodule Gofer.Actions.PipelineDoneImpl do
  @moduledoc """
  Collects actions taken once Gofer realizes that piepeline is done
  """

  alias Gofer.Switch.Model.SwitchQueries
  alias Gofer.Target.Model.TargetQueries
  alias Gofer.Deployment.Model.DeploymentQueries
  alias Gofer.SwitchTrigger.Model.SwitchTriggerQueries
  alias Gofer.SwitchTrigger.Engine.SwitchTriggerSupervisor
  alias Util.ToTuple
  alias Ecto.Multi
  alias Gofer.EctoRepo, as: Repo
  alias LogTee, as: LT

  def proces_ppl_done_request(switch_id, ppl_result, ppl_result_reason) do
    case update_switch_and_start_trigger(switch_id, ppl_result, ppl_result_reason) do
      {:ok, result} ->
        log_if_nothing_to_start(result, switch_id)
        {:ok, {:OK, "Pipeline execution result received and processed."}}

      {:error, {:OK, message}} ->
        {:ok, {:OK, message}}

      {:error, {:RESULT_CHANGED, previous_result}} ->
        {:ok,
         {:RESULT_CHANGED, "Previous result: #{previous_result}, new result: #{ppl_result}."}}

      {:error, {:RESULT_REASON_CHANGED, prev_result_reason}} ->
        {:ok,
         {:RESULT_REASON_CHANGED,
          "Previous result_reason: #{prev_result_reason}, new result_reason: #{ppl_result_reason}."}}

      {:error, {:NOT_FOUND, message}} ->
        {:ok, {:NOT_FOUND, message}}

      {:error, message} ->
        {:error, message} |> LT.error("Switch #{switch_id} - Pipeline Done request failure")

      error ->
        error
        |> ToTuple.error()
        |> LT.error("Switch #{switch_id} - Pipeline Done request failure")
    end
  end

  defp log_if_nothing_to_start(:nothing_to_start, switch_id) do
    LT.info("", "Processing of switch #{switch_id} is done, there is nothing to auto-trigger")
  end

  defp log_if_nothing_to_start(_switch_trigger, _switch_id), do: :continue

  # Functions for updating Switch and starting SwitchTrigger process

  def update_switch_and_start_trigger(switch_id, ppl_result, ppl_result_reason) do
    case run_transaction(switch_id, ppl_result, ppl_result_reason) do
      {:ok, %{start_switch_trigger: result}} ->
        {:ok, result}

      {:error, operation, error, _changes} ->
        LT.error(
          error,
          "update_switch_and_start_trigger() for switch #{switch_id} " <>
            "failed at '#{operation}' with error"
        )

        {:error, error}

      error ->
        LT.error(error, "Switch #{switch_id} - update_switch_and_start_trigger() failed")
        {:error, error}
    end
  end

  defp run_transaction(switch_id, ppl_result, ppl_result_reason) do
    Multi.new()
    |> Multi.run(:update_switch, fn _, _ ->
      update_switch(switch_id, ppl_result, ppl_result_reason)
    end)
    |> Multi.run(:get_targets, fn _, _ ->
      TargetQueries.get_all_targets_for_switch(switch_id)
    end)
    |> Multi.run(:names_to_trigger, fn _, params ->
      %{update_switch: switch, get_targets: targets} = params
      names_of_targets_to_trigger(targets, switch)
    end)
    |> Multi.run(:start_switch_trigger, fn _, params ->
      %{update_switch: switch, get_targets: targets, names_to_trigger: target_names} = params
      start_all_triggers(switch, targets, target_names)
    end)
    |> Repo.transaction()
  end

  defp update_switch(switch_id, ppl_result, ppl_result_reason) do
    with {:ok, switch} <- SwitchQueries.get_by_id(switch_id),
         {:result_same, nil, nil} <-
           {:result_same, Map.get(switch, :ppl_result), Map.get(switch, :ppl_result_reason)} do
      SwitchQueries.update(switch, %{
        "ppl_done" => true,
        "ppl_result" => ppl_result,
        "ppl_result_reason" => ppl_result_reason
      })
    else
      {:result_same, prev_result, prev_result_reason} ->
        result_same?(ppl_result, ppl_result_reason, prev_result, prev_result_reason, switch_id)

      {:error, msg = "Switch with id " <> _rest} ->
        {:error, {:NOT_FOUND, msg}}

      error ->
        error
    end
  end

  defp result_same?(result, reason, prev_result, prev_reason, switch_id)
       when result == prev_result,
       do: reason_same?(reason, prev_reason, switch_id)

  defp result_same?(_result, _, prev_result, _, _),
    do: {:error, {:RESULT_CHANGED, prev_result}}

  defp reason_same?(reason, prev_reason, switch_id)
       when reason == prev_reason,
       do: is_switch_trigger_process_started?(switch_id)

  defp reason_same?("", nil, switch_id),
    do: is_switch_trigger_process_started?(switch_id)

  defp reason_same?(_reason, prev_reason, _switch_id),
    do: {:error, {:RESULT_REASON_CHANGED, prev_reason}}

  defp is_switch_trigger_process_started?(switch_id) do
    case SwitchTriggerQueries.get_by_request_token(switch_id <> "-auto") do
      {:error, "Switch_trigger with" <> _rest} ->
        SwitchQueries.get_by_id(switch_id)

      {:ok, _switch_trigger} ->
        {:error, {:OK, "Pipeline execution result received and processed."}}
    end
  end

  defp names_of_targets_to_trigger(targets, switch) do
    targets
    |> Enum.reduce_while({:ok, []}, fn target, {:ok, names_list} ->
      case should_auto_trigger?(target, switch) do
        true -> {:cont, {:ok, names_list ++ [target.name]}}
        false -> {:cont, {:ok, names_list}}
        {:error, e} -> {:halt, {:error, e}}
        error -> {:halt, {:error, error}}
      end
    end)
  end

  defp should_auto_trigger?(target, switch) do
    with result_a when is_boolean(result_a) <-
           any_auto_trigger_condition_met(target, switch),
         result_b when is_boolean(result_b) <-
           when_condition_satisfied(target, switch) do
      result_a or result_b
    else
      error -> error
    end
  end

  defp when_condition_satisfied(%{auto_promote_when: condition}, switch)
       when is_binary(condition) and condition != "" do
    with {:ok, params} <- when_params(switch, switch.git_ref_type),
         {:ok, result} <- When.evaluate(condition, params) do
      result
    end
  end

  defp when_condition_satisfied(_target, _switch), do: false

  defp when_params(switch, ref_type) when ref_type in ["branch", "tag", "pr"] do
    default_when_params()
    |> Map.put(key(ref_type), switch.label)
    |> Map.put("result", switch.ppl_result)
    |> Map.put("result_reason", switch.ppl_result_reason || "")
    |> Map.put("project_id", switch.project_id)
    |> Map.put("working_dir", switch.working_dir)
    |> Map.put("commit_range", switch.commit_range)
    |> Map.put("yml_file_name", switch.yml_file_name)
    |> Map.put("pr_base", switch.pr_base || "")
    |> set_commit_sha(switch, ref_type)
    |> ToTuple.ok()
  end

  defp when_params(switch, ref_type),
    do: {:error, "Invalid git_ref_type: '#{ref_type}' for switch '#{switch.id}'"}

  defp set_commit_sha(map, switch, "pr") do
    map |> Map.put("commit_sha", switch.pr_sha || "")
  end

  defp set_commit_sha(map, switch, _ref_type) do
    map |> Map.put("commit_sha", switch.commit_sha)
  end

  defp key("pr"), do: "pull_request"
  defp key(ref_type), do: ref_type

  defp default_when_params() do
    %{"branch" => "", "tag" => "", "pull_request" => "", "result" => "", "result_reason" => ""}
  end

  defp any_auto_trigger_condition_met(target, switch) do
    target.auto_trigger_on
    |> Enum.any?(fn condition_map ->
      branch_in_whitelist?(condition_map, switch.branch_name) and
        condition_map["result"] == switch.ppl_result and
        result_reason_matches_or_undefined(condition_map, switch.ppl_result_reason)
    end)
  end

  defp branch_in_whitelist?(%{"labels" => labels}, branch_name) when labels != [] do
    labels |> Enum.find_value(false, fn label -> label == branch_name end)
  end

  defp branch_in_whitelist?(%{"label_patterns" => patterns}, branch_name) when patterns != [] do
    patterns
    |> Enum.any?(fn regex_exp ->
      Regex.match?(~r/#{regex_exp}/, branch_name)
    end)
  end

  defp branch_in_whitelist?(%{"branch" => branches}, branch_name) when branches != [] do
    branches
    |> Enum.any?(fn regex_exp ->
      Regex.match?(~r/#{regex_exp}/, branch_name)
    end)
  end

  defp branch_in_whitelist?(_conditions, _branch_name), do: true

  defp result_reason_matches_or_undefined(condition_map, result_reason) do
    condition_map["result_reason"] |> is_nil() or
      condition_map["result_reason"] == "" or
      condition_map["result_reason"] == result_reason
  end

  defp start_all_triggers(switch, targets, target_names) do
    {targets_without_deployment, targets_with_deployment} =
      targets
      |> Enum.filter(&Enum.member?(target_names, &1.name))
      |> Enum.split_with(&is_nil(&1.deployment_target))

    for target <- targets_with_deployment do
      log_prefix = "Deployment trigger for switch #{switch.id} and target #{target.name} "

      case start_deployment_trigger(switch, target) do
        {:ok, pid} -> LT.debug(pid, log_prefix <> " started")
        error -> LT.error(error, log_prefix <> "failed to start")
      end
    end

    target_names = Enum.into(targets_without_deployment, [], & &1.name)
    start_switch_trigger(switch.id, targets_without_deployment, target_names)
  end

  defp start_deployment_trigger(switch, target) do
    target_name_md5 = target.name |> :erlang.md5() |> Base.encode16(case: :lower)
    request_token_suffix = "-#{target_name_md5}-auto"

    with {:ok, env_vars} <- collect_env_vars([target]),
         {:ok, params} <-
           form_auto_trigger_params(switch.id, [target.name], env_vars, request_token_suffix),
         {:ok, deployment} <-
           DeploymentQueries.find_by_project_and_name(
             switch.project_id,
             target.deployment_target
           ) do
      Gofer.DeploymentTrigger.Engine.Supervisor.start_worker(switch, deployment, params)
    end
  end

  defp start_switch_trigger(_switch_id, _targets, []), do: {:ok, :nothing_to_start}

  defp start_switch_trigger(switch_id, targets, target_names) do
    with {:ok, env_vars} <- param_env_vars_with_default_value(targets, target_names),
         {:ok, params} <- form_auto_trigger_params(switch_id, target_names, env_vars),
         id <- Map.get(params, "id") do
      SwitchTriggerSupervisor.start_switch_trigger_process(id, params)
    end
  end

  defp param_env_vars_with_default_value(targets, target_names) do
    targets
    |> Enum.filter(fn target -> Enum.member?(target_names, target.name) end)
    |> collect_env_vars()
  end

  defp collect_env_vars(targets) do
    targets
    |> Enum.reduce({:ok, %{}}, fn target, {:ok, res_map} ->
      target.parameter_env_vars
      |> get_default_values()
      |> add_to_result(target.name, res_map)
    end)
  end

  defp get_default_values(param_env_vars) do
    param_env_vars
    |> Enum.reduce({:ok, []}, fn {name, pev}, {:ok, acc} ->
      if is_binary(pev["default_value"]) and pev["default_value"] != "" do
        env_var = %{"name" => name, "value" => pev["default_value"]}
        {:ok, acc ++ [env_var]}
      else
        {:ok, acc}
      end
    end)
  end

  defp add_to_result({:ok, env_vars}, target_name, res_map) do
    res_map |> Map.put(target_name, env_vars) |> ToTuple.ok()
  end

  defp form_auto_trigger_params(switch_id, target_names, env_vars, suffix \\ "-auto") do
    %{
      "id" => UUID.uuid4(),
      "switch_id" => switch_id,
      "request_token" => switch_id <> suffix,
      "target_names" => target_names,
      "triggered_by" => "Pipeline Done request",
      "triggered_at" => DateTime.utc_now(),
      "auto_triggered" => true,
      "override" => false,
      "env_vars_for_target" => env_vars,
      "processed" => false
    }
    |> ToTuple.ok()
  end
end
