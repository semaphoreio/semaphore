defmodule Block.TaskApiClient.ScheduleRequestFormatter do
  @moduledoc """
  Module serves to transform task yaml definition into format suitable for creating
  ScheduleRequest proto message for Task service.
  """

  alias Util.{ToTuple, Proto}
  alias InternalApi.Task.ScheduleRequest
  alias InternalApi.Task.ScheduleRequest.FailFast
  @doc """
  Creates ScheduleRequest proto message from task yaml spec
  """
  def to_proto_request(yaml_task_def, additional_params) do
    with {:ok, task_def}      <- transform_from_spec_to_proto_def(yaml_task_def),
         {:ok, {raw_jobs, task_settings}}
                               <- split_task_def(task_def),
         ppl_args              <- Map.get(additional_params, "ppl_args", %{}),
         ppl_priority          <- Map.get(ppl_args, "ppl_priority", 50),
         {:ok, raw_jobs}       <- transform_jobs(raw_jobs, ppl_args, ppl_priority),
         {:ok, jobs}           <- merge_settings(raw_jobs, task_settings),
         {:ok, addit_params}   <- extract_fail_fast(additional_params, task_settings),
         {:ok, request_params} <- form_request_params(jobs, addit_params)
    do
      Proto.deep_new(ScheduleRequest, request_params, string_keys_to_atoms: true,
                    transformations: %{FailFast => {__MODULE__, :string_to_enum_atom}})
    else
      e = {:error, _msg} -> e
      error -> {:error, error}
    end
  end

###########

  defp transform_from_spec_to_proto_def(yaml_task_def) do
    yaml_task_def
    |> prolog_epilog_transformation()
  end

  defp prolog_epilog_transformation(map) do
    map
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case key do
        "prologue" -> Map.put(acc, "prologue_commands", Map.get(value, "commands", []))
        "epilogue" -> trasnform_epilogue(value, acc)
        _  -> Map.put(acc, key, value)
      end
    end)
    |> ToTuple.ok()
  end

  defp trasnform_epilogue(epilogue, map) do
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
    {task_def |> Map.get("jobs", []),
     task_def |> Map.drop(["jobs"])
    } |> ToTuple.ok()
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
    with {:ok, priority}
             <- calculate_priority(priority_conditions, ppl_args, ppl_priority),
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
    with ref_type      <- ppl_args |> Map.get("git_ref_type", ""),
         label         <- ppl_args |> Map.get("label", ""),
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
    do:  map |> Map.put("pr_base", "")

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
    env_vars = Map.get(settings_map, "ppl_env_variables", [])
               ++ Map.get(settings_map, "env_vars", [])
               ++ Map.get(job, "env_vars", [])


    settings_map
    |> Map.merge(job)
    |> Map.put("env_vars", env_vars)
    |> Map.drop(["ppl_env_variables"])
  end

###########

  defp form_request_params(jobs, additional_params) do
    additional_params
    |> Map.put("jobs", jobs)
    |> ToTuple.ok()
  end

###########

  defp extract_fail_fast(params, task_settings) do
    params
    |> Map.drop(["ppl_args"])
    |> Map.put("fail_fast", Map.get(task_settings, "fail_fast"))
    |> ToTuple.ok()
  end

  def string_to_enum_atom(_field_name, field_value)
    when is_binary(field_value) and field_value != "" do
      field_value |> String.upcase() |> String.to_atom()
  end
  def string_to_enum_atom(_field_name, _field_value), do: 0
end
