defmodule Ppl.DefinitionReviser.BlocksReviser do
  require Logger
  @moduledoc """
  Module performs necessary transformations on raw block definition.
  """

  alias Util.ToTuple
  alias Ppl.UserClient
  alias Block.CommandsFileReader.DefinitionRefiner, as: CmdFileReader
  alias Ppl.Ppls.Model.PplsQueries

  @ppl_artefact_id_env_var_name "SEMAPHORE_PIPELINE_ARTEFACT_ID"
  @ppl_id_env_var_name "SEMAPHORE_PIPELINE_ID"
  @ppl_name_env_var_name "SEMAPHORE_PIPELINE_NAME"
  @pipeline_rerun "SEMAPHORE_PIPELINE_RERUN"
  @block_name "SEMAPHORE_BLOCK_NAME"
  @pipeline_promotion "SEMAPHORE_PIPELINE_PROMOTION"
  @pipeline_promoted_by "SEMAPHORE_PIPELINE_PROMOTED_BY"
  @workflow_id_env_var_name "SEMAPHORE_WORKFLOW_ID"
  @snapshot_id_env_var_name "SEMAPHORE_SNAPSHOT_ID"
  @workflow_number_env_var_name "SEMAPHORE_WORKFLOW_NUMBER"
  @workflow_rerun "SEMAPHORE_WORKFLOW_RERUN"
  @workflow_triggered_by_hook "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK"
  @workflow_hook_source "SEMAPHORE_WORKFLOW_HOOK_SOURCE"
  @workflow_triggered_by_schedule "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE"
  @workflow_triggered_by_api "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API"
  @workflow_triggered_by_manual_run "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN"
  @workflow_triggered_by "SEMAPHORE_WORKFLOW_TRIGGERED_BY"
  @git_commit_author "SEMAPHORE_GIT_COMMIT_AUTHOR"
  @git_committer "SEMAPHORE_GIT_COMMITTER"
  @organization_id "SEMAPHORE_ORGANIZATION_ID"

  def revise_blocks_definition(definition, ppl_req) do
    with {:ok, definition} <- do_revise_blocks_definition(definition, ppl_req, "blocks"),
         {:ok, definition} <- do_revise_blocks_definition(definition, ppl_req, "after_pipeline")
    do
      ToTuple.ok(definition)
    end
  end

  defp do_revise_blocks_definition(definition, ppl_req, "blocks") do
    definition = old_epilogue_to_always_epilogue(definition)

    definition
    |> Map.get("blocks", [])
    |> Enum.reduce({:ok, []}, fn block_def, acc ->
      set_additional_fields(acc, block_def, definition, ppl_req)
    end)
    |> process_result(definition, "blocks")
  end

  defp do_revise_blocks_definition(definition, ppl_req, "after_pipeline") do
    Map.get(definition, "after_pipeline")
    |> case do
      nil ->
        {:ok, definition}

      _ ->
        definition = old_epilogue_to_always_epilogue(definition)

        definition
        |> Map.get("after_pipeline", [])
        |> Enum.reduce({:ok, []}, fn block_def, acc ->
          set_additional_after_ppl_fields(acc, block_def, definition, ppl_req)
        end)
        |> process_result(definition, "after_pipeline")
    end
  end

  defp old_epilogue_to_always_epilogue(ppl_def) do
    ppl_def |> Enum.into(%{}, fn {k, v} -> {k, transform_epilogue(k, v)} end)
  end

  defp transform_epilogue("epilogue", %{"commands" => commands}) do
    %{"always" => %{"commands" => commands}}
  end
  defp transform_epilogue("epilogue", %{"commands_file" => file}) do
    %{"always" => %{"commands_file" => file}}
  end
  defp transform_epilogue(_key, value) when is_map(value) do
    value |> Enum.into(%{}, fn {k, v} -> {k, transform_epilogue(k, v)} end)
  end
  defp transform_epilogue(_key, value) when is_list(value) do
    value |> Enum.map(fn elem -> transform_epilogue("", elem) end)
  end
  defp transform_epilogue(_key, value), do: value

  defp process_result(error = {:error, _e}, _ppl_def, _root_name), do: error
  defp process_result({:ok, blocks}, ppl_def, root_name),
    do: ppl_def |> Map.update!(root_name, fn _value -> blocks end) |> ToTuple.ok()

  defp set_additional_fields(error = {:error, _e}, _, _, _), do: error
  defp set_additional_fields({:ok, blocks}, block_def, ppl_def, ppl_req) do
    with {:ok, block_def}  <- set_agent(block_def, ppl_def),
         {:ok, ppl_def}    <- global_config_cmd_file_to_cmds(ppl_def, ppl_req.request_args),
         {:ok, block_def}  <- merge_with_global_job_config(block_def, ppl_def),
         {:ok, block_def}  <- set_ppl_env_vars(block_def, ppl_def, ppl_req)
    do
      blocks ++ [block_def] |> ToTuple.ok()
    else
      error -> error |> inspect() |> ToTuple.error()
    end
  end

  defp set_additional_after_ppl_fields(error = {:error, _e}, _, _, _), do: error
  defp set_additional_after_ppl_fields({:ok, blocks}, block_def, ppl_def, ppl_req) do
    with {:ok, block_def}  <- set_agent(block_def, ppl_def),
         {:ok, block_def}  <- set_ppl_env_vars(block_def, ppl_def, ppl_req)
    do
      blocks ++ [block_def] |> ToTuple.ok()
    else
      error -> error |> inspect() |> ToTuple.error()
    end
  end

  def set_ppl_env_vars(block_def, ppl_def, ppl_req) do
    with {:ok, ppl}        <- PplsQueries.get_by_id(ppl_req.id),
         {:ok, promoter}   <- promoted_by?(ppl_req.request_args),
         {:ok, triggerer}  <- triggered_by?(ppl_req),
    do: set_ppl_env_vars_(block_def, ppl_def, ppl_req, ppl, promoter, triggerer)
  end

  defp promoted_by?(%{"auto_promoted" => true}), do: {:ok, "auto-promotion"}
  defp promoted_by?(%{"promoter_id" => user_id})
       when is_binary(user_id) and user_id != "" do
    case UserClient.describe(user_id) do
      {:ok, user} -> {:ok, user.github_login}
      error -> error
    end
  end
  defp promoted_by?(_), do: {:ok, ""}

  defp triggered_by?(%{request_args: %{"requester_id" => requester_id}})
       when is_binary(requester_id) and requester_id != "" do
    case UserClient.describe(requester_id) do
      {:ok, user} -> {:ok, user.github_login}
      error -> error
    end
  end
  defp triggered_by?(%{source_args: source_args}) when is_map(source_args) do
    repo_host_username = Map.get(source_args, "repo_host_username", "")
    commit_author = Map.get(source_args, "repo_host_username", "")

    if repo_host_username != "",
      do: {:ok, repo_host_username},
      else: {:ok, commit_author}
  end
  defp triggered_by?(_ppl_req), do: {:ok, ""}

  defp set_agent(block_def, ppl_def) do
    block_def
    |> get_in(["build", "agent"])
    |> get_block_agent(Map.get(ppl_def, "agent"))
    |> set_agent_(block_def)
  end

  defp get_block_agent(nil, ppl_agent), do: ppl_agent
  defp get_block_agent(_, _), do: :already_set

  defp set_agent_(:already_set, block_def), do: {:ok, block_def}
  defp set_agent_(agent, block_def),
    do: {:ok, put_in(block_def, ["build", "agent"], agent)}

  defp global_config_cmd_file_to_cmds(ppl_def, args) do
    with global_cfg        <- Map.get(ppl_def, "global_job_config", %{}),
         request_secrets   <- Map.get(args, "request_secrets", []),
         global_cfg        <- Map.update(global_cfg, "secrets", request_secrets, &(request_secrets ++ &1)),
         epilogue          <- Map.get(global_cfg, "epilogue", %{}),
         {:ok, global_cfg} <- CmdFileReader.to_commands(global_cfg, "prologue", args),
         {:ok, epilogue}   <- CmdFileReader.to_commands(epilogue, "always", args),
         {:ok, epilogue}   <- CmdFileReader.to_commands(epilogue, "on_pass", args),
         {:ok, epilogue}   <- CmdFileReader.to_commands(epilogue, "on_fail", args),
         global_cfg        <- Map.put(global_cfg, "epilogue", epilogue)
    do
      ppl_def |> Map.put("global_job_config", global_cfg) |> ToTuple.ok()
    end
  end

  defp merge_with_global_job_config(block_def, ppl_def) do
    block_def
    |> add_defult_empty_configs()
    |> merge_global_config_for(["secrets"], ppl_def)
    |> merge_global_config_for(["env_vars"], ppl_def)
    |> merge_global_config_for(["prologue", "commands"], ppl_def)
    |> merge_global_config_for(["epilogue", "always", "commands"], ppl_def, :block_first)
    |> merge_global_config_for(["epilogue", "on_pass", "commands"], ppl_def, :block_first)
    |> merge_global_config_for(["epilogue", "on_fail", "commands"], ppl_def, :block_first)
    |> merge_priorities(ppl_def["global_job_config"])
  end

  defp add_defult_empty_configs(block_def = %{"build" => _build}) do
    empty_configs()
    |> DeepMerge.deep_merge(block_def)
    |> ToTuple.ok()
  end
  defp add_defult_empty_configs(block_def), do: {:ok, block_def}

  defp empty_configs() do
    cmds = %{"commands" => []}
    %{"build" => %{"secrets" => [], "env_vars" => [], "prologue" => cmds,
                   "epilogue" => %{"always" => cmds, "on_pass" => cmds,
                   "on_fail" => cmds}}}
  end

  defp merge_priorities({:ok, block_def}, %{"priority" => priorities}) do
    jobs =
      block_def
      |> get_in(["build", "jobs"])
      |> Enum.map(fn job -> merge_job_priority(job, priorities) end)

    put_in(block_def, ["build", "jobs"], jobs) |> ToTuple.ok()
  end
  defp merge_priorities({:ok, block_def}, _global_job_config), do: {:ok, block_def}
  defp merge_priorities(error, _global_job_config), do: error

  defp merge_job_priority(job = %{"priority" => job_priorities}, global_priorities) do
    Map.put(job, "priority", job_priorities ++ global_priorities)
  end
  defp merge_job_priority(job, global_priorities) do
    Map.put(job, "priority", global_priorities)
  end

  defp merge_global_config_for(block_def_tuple, keys, ppl_def, order \\ :global_first)
  defp merge_global_config_for({:ok, block_def}, keys, ppl_def, order) do
    with block_vals  <- get_in(block_def, ["build"] ++ keys) || [],
         global_vals <- get_in(ppl_def, ["global_job_config"] ++ keys) || [],
         merged_vals <- merge_vals(global_vals, block_vals, order)
    do
      block_def |> put_in(["build"] ++ keys, merged_vals) |> ToTuple.ok()
    end
  end
  defp merge_global_config_for(e = {:error, _msg}, _keys, _ppl_def, _order), do: e
  defp merge_global_config_for(error, _keys, _ppl_def, _order), do: {:error, error}

  defp merge_vals(global_vals, block_vals, :global_first), do: global_vals ++ block_vals
  defp merge_vals(global_vals, block_vals, :block_first), do: block_vals ++ global_vals

  defp set_ppl_env_vars_(block_def, ppl_def, ppl_req, ppl, promoter, triggerer) do
    ppl_env_vars =
      ppl_req
      |> basic_env_vars(ppl_def, ppl, promoter, triggerer, block_def)
      |> env_vars_from_prev_ppl_artefact_ids(ppl_req.prev_ppl_artefact_ids ++ [ppl_req.ppl_artefact_id])
      |> Enum.concat(Map.get(ppl_req.request_args, "env_vars", []))

    block_def
    |> put_in(["build", "ppl_env_variables"], ppl_env_vars)
    |> ToTuple.ok()
  end

  defp env_vars_from_prev_ppl_artefact_ids(list, prev_ppl_artefact_ids) do
    prev_ids_env_vars =
      prev_ppl_artefact_ids
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        %{"name" => "SEMAPHORE_PIPELINE_#{index}_ARTEFACT_ID", "value" => "#{value}"}
      end)
    list ++ prev_ids_env_vars
  end

  defp basic_env_vars(ppl_req, ppl_def, ppl, promoter, triggerer, block_def) do
    snapshot_id = get_snapshot_id(ppl_req.request_args)
    block_name = get_block_name(block_def)
    organization_id = get_organization_id(ppl_req.request_args)

    [
     %{"name" => @workflow_id_env_var_name, "value" => "#{ppl_req.wf_id}"},
     %{"name" => @workflow_number_env_var_name, "value" => "#{ppl.wf_number}"},
     %{"name" => @workflow_rerun, "value" => rerun?(ppl_req.request_args)},
     %{"name" => @workflow_triggered_by_hook, "value" => hook?(ppl_req.request_args)},
     %{"name" => @workflow_hook_source, "value" => "github"},
     %{"name" => @workflow_triggered_by_schedule, "value" => schedule?(ppl_req.request_args)},
     %{"name" => @workflow_triggered_by_api, "value" => api?(ppl_req.request_args)},
     %{"name" => @workflow_triggered_by_manual_run, "value" => manual_run?(ppl_req.request_args)},
     %{"name" => @ppl_artefact_id_env_var_name, "value" => "#{ppl_req.ppl_artefact_id}"},
     %{"name" => @ppl_id_env_var_name, "value" => "#{ppl_req.id}"},
     %{"name" => @ppl_name_env_var_name, "value" => "#{ppl_def["name"]}"},
     %{"name" => @block_name, "value" => block_name},
     %{"name" => @pipeline_rerun, "value" => ppl_rerun?(ppl.partial_rebuild_of)},
     %{"name" => @pipeline_promotion, "value" => promotion?(ppl.extension_of)},
     %{"name" => @pipeline_promoted_by, "value" => promoter},
     %{"name" => @workflow_triggered_by, "value" => triggerer},
     %{"name" => @git_commit_author, "value" => commit_author(ppl_req.source_args)},
     %{"name" => @git_committer, "value" => committer(ppl_req.source_args)},
     %{"name" => @organization_id, "value" => organization_id},
    ]
    |> Enum.concat(snapshot_id_env_var(snapshot_id))
  end

  defp rerun?(%{"wf_rebuild_of" => val}) when is_binary(val) and val != "", do: "true"
  defp rerun?(_), do: "false"

  defp hook?(%{"triggered_by" => "schedule"}), do: "false"
  defp hook?(%{"triggered_by" => "api"}), do: "false"
  defp hook?(_), do: "true"

  defp schedule?(%{"triggered_by" => "schedule"}), do: "true"
  defp schedule?(_), do: "false"

  defp api?(%{"triggered_by" => "api"}), do: "true"
  defp api?(_), do: "false"

  defp manual_run?(%{"triggered_by" => "manual_run"}), do: "true"
  defp manual_run?(_), do: "false"

  defp ppl_rerun?(uuid) when is_binary(uuid) and uuid != "", do: "true"
  defp ppl_rerun?(_), do: "false"

  defp promotion?(uuid) when is_binary(uuid) and uuid != "", do: "true"
  defp promotion?(_), do: "false"

  defp snapshot_id_env_var(_snapshot_id = ""), do: []
  defp snapshot_id_env_var(snapshot_id),
    do: [%{"name" => @snapshot_id_env_var_name, "value" => "#{snapshot_id}"}]

  defp get_snapshot_id(request_args), do: Map.get(request_args, "snapshot_id", "")

  defp get_organization_id(request_args), do: Map.get(request_args, "organization_id", "")

  defp commit_author(source_args) when is_map(source_args),
    do: Map.get(source_args, "commit_author", "")
  defp commit_author(_), do: ""

  defp committer(source_args) when is_map(source_args),
    do: Map.get(source_args, "repo_host_username", "")
  defp committer(_source_args), do: ""

  defp get_block_name(%{"name" => name}), do: name
  defp get_block_name(_block_def), do: ""
end
