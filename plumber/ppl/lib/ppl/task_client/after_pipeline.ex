defmodule Ppl.TaskClient.AfterPipeline do
  @moduledoc """
  Handles all actions on Zebra that are connected with after pipeline tasks
  """

  alias JobMatrix.Handler, as: JobMatrixHandler
  alias JobMatrix.ParallelismHandler, as: ParallelismHandler
  alias Util.ToTuple

  def start(
        ppl_req = %{definition: ppl_definition, request_args: additional_params},
        after_ppl,
        ppl_trace,
        ppl
      ) do
    with {:ok, task_definition} <- prepare_task_definition(ppl_definition),
         {:ok, task_definition} <- inject_pipeline_metrics(task_definition, ppl_trace, ppl),
         {:ok, task_definition} <- prologue_epilogue_transformation(task_definition),
         {:ok, task_definition} <- matrix_transformations(task_definition),
         {:ok, {raw_jobs, task_settings}} <- split_task_def(task_definition),
         ppl_args <- Map.get(additional_params, "ppl_args", %{}),
         ppl_priority <- Map.get(ppl_args, "ppl_priority", 45),
         {:ok, raw_jobs} <- transform_jobs(raw_jobs, ppl_args, ppl_priority),
         {:ok, jobs} <- merge_settings(raw_jobs, task_settings),
         {:ok, request_params} <- form_request_params(jobs, ppl_req),
         {:ok, request_params} <- form_request_token(after_ppl, request_params),
         task_params <- [task_definition, request_params, Ppl.TaskClient.task_api_url()],
         {:ok, result} <- Ppl.TaskClient.schedule(task_params),
         do: handle_schedule_result(result)
  end

  defp prepare_task_definition(%{"after_pipeline" => [after_pipeline | _]}) do
    after_pipeline
    |> Map.get("build")
    |> ToTuple.ok()
  end

  defp matrix_transformations(task_definition) do
    jobs =
      with jobs <- Map.get(task_definition, "jobs", []),
           {:ok, jobs} <- ParallelismHandler.handle_jobs(jobs),
           {:ok, jobs} <- JobMatrixHandler.handle_jobs(jobs) do
        jobs
      end

    task_definition
    |> Map.put("jobs", jobs)
    |> ToTuple.ok()
  end

  ###########

  defp inject_pipeline_metrics(task_definition, ppl_trace, ppl) do
    current_env_variables =
      task_definition
      |> Map.get("ppl_env_variables", [])

    env_to_inject = %{
      "SEMAPHORE_PIPELINE_TOTAL_DURATION" =>
        "#{DateTime.to_unix(ppl_trace.done_at) - DateTime.to_unix(ppl_trace.created_at)}",
      "SEMAPHORE_PIPELINE_INIT_DURATION" =>
        "#{DateTime.to_unix(ppl_trace.pending_at) - DateTime.to_unix(ppl_trace.created_at)}",
      "SEMAPHORE_PIPELINE_QUEUEING_DURATION" =>
        "#{DateTime.to_unix(ppl_trace.queuing_at) - DateTime.to_unix(ppl_trace.created_at)}",
      "SEMAPHORE_PIPELINE_RUNNING_DURATION" =>
        "#{DateTime.to_unix(ppl_trace.done_at) - DateTime.to_unix(ppl_trace.running_at)}",
      "SEMAPHORE_PIPELINE_CREATED_AT" => "#{DateTime.to_unix(ppl_trace.created_at)}",
      "SEMAPHORE_PIPELINE_STARTED_AT" => "#{DateTime.to_unix(ppl_trace.running_at)}",
      "SEMAPHORE_PIPELINE_DONE_AT" => "#{DateTime.to_unix(ppl_trace.done_at)}"
    }

    result =
      ppl.result
      |> case do
        nil -> "failed"
        result -> result
      end

    env_to_inject = Map.put(env_to_inject, "SEMAPHORE_PIPELINE_RESULT", result)

    result_reason =
      ppl.result_reason
      |> case do
        nil -> ""
        reason -> reason
      end

    env_to_inject = Map.put(env_to_inject, "SEMAPHORE_PIPELINE_RESULT_REASON", result_reason)

    injected_env_variables =
      env_to_inject
      |> Enum.map(fn {env_name, env_value} ->
        %{"name" => env_name, "value" => env_value}
      end)

    task_definition
    |> Map.put("ppl_env_variables", current_env_variables ++ injected_env_variables)
    |> ToTuple.ok()
  end

  ###########
  defp prologue_epilogue_transformation(definition) do
    definition
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case key do
        "prologue" -> Map.put(acc, "prologue_commands", Map.get(value, "commands", []))
        "epilogue" -> transform_epilogue(value, acc)
        _ -> Map.put(acc, key, value)
      end
    end)
    |> ToTuple.ok()
  end

  defp transform_epilogue(epilogue, map) do
    map
    |> Map.put("epilogue_always_cmds", get_cmds(epilogue, "always"))
    |> Map.put("epilogue_on_pass_cmds", get_cmds(epilogue, "on_pass"))
    |> Map.put("epilogue_on_fail_cmds", get_cmds(epilogue, "on_fail"))
  end

  defp get_cmds(epilogue, key) do
    epilogue |> Map.get(key, %{}) |> Map.get("commands", [])
  end

  ###########

  defp split_task_def(task_def) do
    {task_def |> Map.get("jobs", []), task_def |> Map.drop(["jobs"])} |> ToTuple.ok()
  end

  ###########

  defp transform_jobs(raw_jobs, ppl_args, ppl_priority) do
    Enum.reduce_while(raw_jobs, {:ok, []}, fn raw_job, {:ok, jobs} ->
      raw_job
      |> set_exec_time_limit()
      |> set_priority(ppl_args, ppl_priority)
      |> case do
        {:ok, job} -> {:cont, {:ok, jobs ++ [job]}}
        error -> {:halt, error}
      end
    end)
  end

  ###########

  defp set_exec_time_limit(job = %{"execution_time_limit" => limits}) do
    limit = Map.get(limits, "minutes", 0) + Map.get(limits, "hours", 0) * 60

    job |> Map.put("execution_time_limit", limit)
  end

  defp set_exec_time_limit(job) when is_map(job), do: job

  ###########

  defp set_priority(job = %{"priority" => priority_conditions}, ppl_args, ppl_priority) do
    with {:ok, priority} <- calculate_priority(priority_conditions, ppl_args, ppl_priority),
         do: job |> Map.put("priority", priority) |> ToTuple.ok()
  end

  defp set_priority(job, _ppl_args, ppl_priority) do
    job |> Map.put("priority", ppl_priority) |> ToTuple.ok()
  end

  defp calculate_priority(priority_conditions, ppl_args, ppl_priority) do
    priority_conditions
    |> Enum.reduce_while({:ok, ppl_priority}, fn priority_cond, acc ->
      priority_cond
      |> Map.get("when")
      |> evaulate_condition(ppl_args)
      |> case do
        {:ok, true} -> {:halt, {:ok, priority_cond |> Map.get("value")}}
        {:ok, false} -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  ###########

  defp evaulate_condition(bool_value, _ppl_args) when is_boolean(bool_value),
    do: {:ok, bool_value}

  defp evaulate_condition(when_expr, ppl_args) when is_binary(when_expr) do
    with ref_type <- ppl_args |> Map.get("git_ref_type", ""),
         label <- ppl_args |> Map.get("label", ""),
         {:ok, params} <- when_params(ppl_args, label, ref_type),
         do: When.evaluate(when_expr, params)
  end

  defp when_params(ppl_args, label, ref_type) when ref_type in ["branch", "tag", "pr"] do
    ppl_args
    |> default_when_params()
    |> Map.put(key(ref_type), label)
    |> add_pr_base?(ppl_args, ref_type)
    |> use_pr_head_commit?(ppl_args, ref_type)
    |> ToTuple.ok()
  end

  defp when_params(ppl_args, _label, _ref_type),
    do: default_when_params(ppl_args) |> ToTuple.ok()

  defp key("pr"), do: "pull_request"
  defp key(ref_type), do: ref_type

  defp default_when_params(ppl_args) do
    ppl_args
    |> Map.take(["working_dir", "commit_sha", "project_id", "commit_range"])
    |> Map.put("yml_file_name", ppl_args["file_name"] || "")
    |> Map.merge(%{"branch" => "", "tag" => "", "pull_request" => ""})
  end

  defp add_pr_base?(map, ppl_args, "pr"),
    do: map |> Map.put("pr_base", ppl_args["branch_name"] || "")

  defp add_pr_base?(map, _ppl_args, _ref_type),
    do: map |> Map.put("pr_base", "")

  defp use_pr_head_commit?(map, ppl_args, "pr"),
    do: map |> Map.put("commit_sha", ppl_args["pr_sha"] || "")

  defp use_pr_head_commit?(map, _ppl_args, _ref_type), do: map

  ###########

  defp merge_settings(jobs, settings_map) when is_list(jobs) do
    jobs
    |> Enum.map(fn job -> merge_settings(job, settings_map) end)
    |> ToTuple.ok()
  end

  defp merge_settings(job, settings_map) do
    env_vars =
      Map.get(settings_map, "ppl_env_variables", []) ++
        Map.get(settings_map, "env_vars", []) ++ Map.get(job, "env_vars", [])

    settings_map
    |> Map.merge(job)
    |> Map.put("env_vars", env_vars)
    |> Map.drop(["ppl_env_variables"])
  end

  ###########

  defp form_request_params(jobs, ppl_req) do
    %{
      "wf_id" => ppl_req.wf_id,
      "ppl_id" => ppl_req.id,
      # ppl_id can be used here because there is only one compile task per pipeline
      "project_id" => ppl_req.request_args |> Map.get("project_id", ""),
      "org_id" => ppl_req.request_args |> Map.get("organization_id", ""),
      "hook_id" => ppl_req.request_args |> Map.get("hook_id", ""),
      "deployment_target_id" => ppl_req.request_args |> Map.get("deployment_target_id", ""),
      # this is currently needed for evaluating When expressions in job priority settings
      # it can be removed once that code is removed
      "ppl_args" => ppl_req.request_args |> Map.merge(ppl_req.source_args || %{})
    }
    |> Map.put("jobs", jobs)
    |> ToTuple.ok()
  end

  ###########

  def apply_after_pipeline_tasks(task_definition = %{"after_pipeline" => after_pipeline}) do
    task_definition
    |> Map.put("blocks", after_pipeline)
    |> Map.drop(["after_pipeline"])
    |> ToTuple.ok()
  end

  ###########

  defp form_request_token(after_ppl, additional_params) do
    id = UUID.uuid3(after_ppl.ppl_id, "#{after_ppl.id}")

    additional_params
    |> Map.put("request_token", id)
    |> ToTuple.ok()
  end

  def string_to_enum_atom(_field_name, field_value)
      when is_binary(field_value) and field_value != "" do
    field_value |> String.upcase() |> String.to_atom()
  end

  def string_to_enum_atom(_field_name, _field_value), do: 0

  defp handle_schedule_result({:ok, task}), do: {:ok, task.id}
  defp handle_schedule_result(error = {:error, _error}), do: error
  defp handle_schedule_result(error), do: {:error, error}
end
