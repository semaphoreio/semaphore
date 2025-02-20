defmodule Ppl.PplsReviser do
  @moduledoc """
  Module serves to make necessary updates on Ppl record on db
  """

  alias Ppl.Ppls.Model.{Ppls, PplsQueries}
  alias Ppl.Queues.Model.QueuesQueries
  alias Util.ToTuple
  alias Ppl.EctoRepo, as: Repo

  @default_time_limit_min 60

  @master_promotion_priority 65
  @master_priority 60
  @promotion_priority 55
  @default_priority 50
  @scheduler_priority 40

  def update_ppl(ppl_req, definition, source_args, with_after_task? \\ false) do
    with {:ok, ppl}          <- PplsQueries.get_by_id(ppl_req.id),
         {:ok, name}         <- get_name(definition),
         ref_type            <- source_args |> Map.get("git_ref_type", ""),
         ppl_args            <- make_ppl_args(source_args, ppl_req.request_args),
         {:ok, fast_failing} <- decide_on_fail_fast(definition, ppl_args, ppl.label, ref_type),
         {:ok, time_limit}   <- get_exec_time_limit(definition),
         {:ok, auto_cancel}  <- set_auto_cancel(definition, ppl_args, ppl.label, ref_type),
         {:ok, priority}     <- set_priority(ppl, definition, ppl_args),
         {:ok, queue_data}   <- set_queue(ppl, definition, ppl_args),
         params              <- %{name: name, fast_failing: fast_failing,
                                priority: priority, parallel_run: queue_data.in_parallel?,
                                queue_id: queue_data.queue_id, auto_cancel: auto_cancel,
                                exec_time_limit_min: time_limit, with_after_task: with_after_task?}
    do
      ppl |> Ppls.changeset(params) |> Repo.update()
    end
  end

  defp get_name(definition),
    do: definition |> Map.get("name", "Pipeline") |> ToTuple.ok()

  defp make_ppl_args(src_args, req_args)
    when is_map(src_args) and is_map(req_args), do: Map.merge(req_args, src_args)
  defp make_ppl_args(_src_args, req_args) when is_map(req_args), do: req_args
  defp make_ppl_args(_src_args, _req_args), do: %{}

  defp set_queue(ppl, %{"queue" => queue_def}, ppl_args) do
    with {:ok, name, scope, in_parallel?, user_generated?}
                       <- get_queue_details(queue_def, ppl, ppl_args),
         {:ok, params} <- form_queue_params(ppl_args, name, scope, user_generated?),
         {:ok, queue}  <- QueuesQueries.get_or_insert_queue(params)
    do
       {:ok, %{queue_id: queue.queue_id, in_parallel?: in_parallel?}}
    end
  end
  defp set_queue(ppl, _definition, ppl_args) do
    with name               <- "#{ppl.label}-#{ppl.yml_file_path}",
         {:ok, params}      <- form_queue_params(ppl_args, name, "project"),
         {:ok, queue}       <- QueuesQueries.get_or_insert_queue(params),
    do: {:ok, %{queue_id: queue.queue_id, in_parallel?: false}}
  end

  defp get_queue_details(queue_map, ppl, _ppl_args) when is_map(queue_map) do
    with name            <- Map.get(queue_map, "name", false),
         user_generated? <- name != false,
         name            <- name || "#{ppl.label}-#{ppl.yml_file_path}",
         scope           <- Map.get(queue_map, "scope", "project"),
         processing      <- Map.get(queue_map, "processing", "serialized"),
         in_parallel?    <- processing == "parallel",
    do: {:ok, name, scope, in_parallel?, user_generated?}
  end

  defp get_queue_details(queue_list, ppl, ppl_args) when is_list(queue_list) do
    default_queue_name = "#{ppl.label}-#{ppl.yml_file_path}"
    default = {:ok, default_queue_name, "project", false, false}

    ref_type = Map.get(ppl_args, "git_ref_type", "")
    {:ok, w_params} = when_params(ppl_args, ppl.label, ref_type)

    queue_list
    |> Enum.reduce_while(default, fn queue_map, acc ->
      queue_map
      |> evaluate_when_(w_params)
      |> case do
        {:ok, true} -> {:halt, get_queue_details(queue_map, ppl, ppl_args)}
        {:ok, false} -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp form_queue_params(request_args, name, scope, user_generated \\ false) do
    %{
      name: name,
      scope: scope,
      project_id: request_args["project_id"],
      organization_id: request_args["organization_id"],
      user_generated: user_generated
    }  |> ToTuple.ok()
  end

  defp set_priority(ppl, _definition, ppl_args) do
    default_priority(ppl_args, promotion?(ppl.extension_of))
  end

  defp promotion?(uuid) when is_binary(uuid) and uuid != "", do: true
  defp promotion?(_), do: false

  defp default_priority(ppl_args, is_promotion?) do
    cond do
      ppl_args["triggered_by"] == "schedule" ->
        {:ok, @scheduler_priority}

      ppl_args["branch_name"] ==  "master" and is_promotion? ->
        {:ok, @master_promotion_priority}

      ppl_args["branch_name"] ==  "master" ->
        {:ok, @master_priority}

      is_promotion? ->
        {:ok, @promotion_priority}

      true ->
        {:ok, @default_priority}
    end
  end

  defp set_auto_cancel(%{"auto_cancel" => cancelation}, ppl_args,  label, ref_type) do
    with {:ok, params}  <- when_params(ppl_args, label, ref_type),
         {:ok, stop?}   <- evaluate_when(cancelation, "running", params),
         {:ok, cancel?} <- evaluate_when(cancelation, "queued", params)
    do
      make_decision(stop?, cancel?)
    end
  end
  defp set_auto_cancel(_definition, _ppl_args, _label, _ref_type), do: {:ok, "none"}

  defp evaluate_when(map, key, params) do
    map |> Map.get(key) |> evaluate_when_(params)
  end

  defp evaluate_when_(%{"when" => condition}, params) when is_binary(condition) do
      When.evaluate(condition, params)
  end
  defp evaluate_when_(%{"when" => bool}, _p) when is_boolean(bool), do: {:ok, bool}
  defp evaluate_when_(_condition, _params), do: {:ok, false}

  defp decide_on_fail_fast(%{"fail_fast" => ff_settings}, ppl_args, label, ref_type) do
    with {:ok, params}  <- when_params(ppl_args, label, ref_type),
         {:ok, stop?}   <- evaluate_when(ff_settings, "stop", params),
         {:ok, cancel?} <- evaluate_when(ff_settings, "cancel", params)
    do
      make_decision(stop?, cancel?)
    end
  end
  defp decide_on_fail_fast(_definition, _ppl_args, _branch, _ref_type), do: {:ok, "none"}

  defp when_params(ppl_args, label, ref_type) when ref_type in ["branch", "tag", "pr"] do
    default_when_params(ppl_args)
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

  defp make_decision(true, _cancel?), do: {:ok, "stop"}
  defp make_decision(_stop?, true), do: {:ok, "cancel"}
  defp make_decision(_stop?, _cancel?), do: {:ok, "none"}

  defp get_exec_time_limit(definition),
    do: definition |> Map.get("execution_time_limit") |> to_minutes() |> ToTuple.ok()

  defp to_minutes(nil), do:  @default_time_limit_min
  defp to_minutes(limit_map) do
    Map.get(limit_map, "minutes", 0) + Map.get(limit_map, "hours", 0) * 60
  end
end
