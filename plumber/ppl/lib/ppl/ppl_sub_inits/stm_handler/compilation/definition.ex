defmodule Ppl.PplSubInits.STMHandler.Compilation.Definition do
  @moduledoc """
  Holds YAML definition of compile task stored as an Elixir map for easier handling.
  """

  alias Util.ToTuple
  alias Ppl.DefinitionReviser.BlocksReviser

  @default_execution_limit_in_minutes 10
  @default_priority 95

  @missing_machine_type_msg "Machine type and OS image for initialization job are not defined"

  def form_definition(ppl_req, pfcs, settings, mix_env) when mix_env in [:test, :stopping_test] do
    case agent_definition(pfcs, settings) do
      {:ok, agent_def} ->
        %{
          "agent" => agent_def,
          "jobs" => [
            %{
              "name" => "Only used in tests",
              "commands" => commands(pfcs, mix_env),
              "secrets" => secrets_definition(pfcs, Map.get(ppl_req, :request_args, %{}))
            }
          ]
        }
        |> ToTuple.ok()

      error ->
        error
    end
  end

  def form_definition(ppl_req = %{request_args: _req_args}, pfcs, settings, _mix_env) do
    case agent_definition(pfcs, settings) do
      {:ok, agent_def} ->
        {:ok, %{"agent" => agent_def, "jobs" => form_defintion_jobs(ppl_req, pfcs)}}

      error ->
        error
    end
  end

  defp form_defintion_jobs(ppl_req = %{request_args: req_args}, pfcs) do
    pfc_cmds = pfc_commands(pfcs)
    org_id = Map.get(req_args, "organization_id", "")

    [
      %{
        "name" => "Compilation",
        "execution_time_limit" => %{"minutes" => @default_execution_limit_in_minutes},
        "priority" => [%{"value" => @default_priority, "when" => true}],
        "env_vars" => ppl_env_vars(ppl_req) ++ [sem_yaml_file_path_env_var(req_args)],
        "secrets" => secrets_definition(pfcs, req_args),
        "commands" =>
          default_commands(req_args, optimize_checkout?(org_id, pfc_cmds)) ++ pfc_cmds,
        "epilogue_always_cmds" => epilogue_always_commands()
      }
    ]
  end

  # The optimized blobless + sparse checkout is used only when both hold:
  #   * there are no pre-flight checks (their custom commands may need the full
  #     working tree), and
  #   * the `sparse_checkout_init_job` feature is enabled for the organization.
  # The feature check fails closed, so a missing org id or an unreachable
  # Feature service keeps the standard full checkout.
  @doc false
  def optimize_checkout?(org_id, pfc_cmds) do
    pfc_cmds == [] and Ppl.Features.sparse_checkout_init_job_enabled?(org_id)
  end

  defp agent_definition(pre_flight_checks, settings) when is_map(pre_flight_checks) do
    pfc_agent = get_in(pre_flight_checks, ["project_pfc", "agent"]) || %{}

    {machine_type, os_image} =
      cond do
        pfc_agent["machine_type"] && String.length(pfc_agent["machine_type"]) > 0 ->
          {pfc_agent["machine_type"], pfc_agent["os_image"]}

        settings["custom_machine_type"] && String.length(settings["custom_machine_type"]) > 0 ->
          {settings["custom_machine_type"], settings["custom_os_image"]}

        true ->
          {settings["plan_machine_type"], settings["plan_os_image"]}
      end

    if machine_type && String.length(machine_type) > 0,
      do: {:ok, %{"machine" => %{"type" => machine_type, "os_image" => os_image || ""}}},
      else: {:error, {:malformed, @missing_machine_type_msg}}
  end

  defp agent_definition(_pre_flight_checks, settings) do
    {machine_type, os_image} =
      if settings["custom_machine_type"] && String.length(settings["custom_machine_type"]) > 0,
        do: {settings["custom_machine_type"], settings["custom_os_image"]},
        else: {settings["plan_machine_type"], settings["plan_os_image"]}

    if machine_type && String.length(machine_type) > 0,
      do: {:ok, %{"machine" => %{"type" => machine_type, "os_image" => os_image || ""}}},
      else: {:error, {:malformed, @missing_machine_type_msg}}
  end

  defp secrets_definition(pfcs, request_args) do
    pipeline_secrets = Map.get(request_args, "request_secrets", [])
    secrets_from_pfcs = pfcs |> pfc_secrets() |> Enum.into([], &%{"name" => &1})
    pipeline_secrets ++ secrets_from_pfcs
  end

  defp pfc_secrets(%{"organization_pfc" => org_pfc, "project_pfc" => prj_pfc})
       when is_map(org_pfc) and is_map(prj_pfc),
       do: Map.get(org_pfc, "secrets", []) ++ Map.get(prj_pfc, "secrets", [])

  defp pfc_secrets(%{"organization_pfc" => org_pfc}) when is_map(org_pfc),
    do: Map.get(org_pfc, "secrets", [])

  defp pfc_secrets(%{"project_pfc" => prj_pfc}) when is_map(prj_pfc),
    do: Map.get(prj_pfc, "secrets", [])

  defp pfc_secrets(_ppl_req), do: []

  defp commands(pfcs, mix_env) when mix_env in [:test, :stopping_test] do
    test_commands(mix_env) ++ pfc_commands(pfcs)
  end

  defp pfc_commands(%{"organization_pfc" => org_pfc, "project_pfc" => prj_pfc})
       when is_map(org_pfc) and is_map(prj_pfc),
       do: Map.get(org_pfc, "commands", []) ++ Map.get(prj_pfc, "commands", [])

  defp pfc_commands(%{"organization_pfc" => org_pfc}) when is_map(org_pfc),
    do: Map.get(org_pfc, "commands", [])

  defp pfc_commands(%{"project_pfc" => prj_pfc}) when is_map(prj_pfc),
    do: Map.get(prj_pfc, "commands", [])

  defp pfc_commands(_ppl_req), do: []

  # When there are no pre-flight checks, the initialization job only needs the
  # pipeline YAML and the Git history (trees/commits, used by `change_in`), not
  # the full repository working tree. In that case we instruct `checkout` to
  # perform a blobless partial clone with a sparse working tree limited to the
  # pipeline directory, which avoids downloading/materializing the whole repo.
  #
  # When pre-flight checks are configured, their custom commands run after the
  # predefined ones and may rely on the full working tree being present, so we
  # keep the standard full checkout.
  @doc false
  def default_commands(req_args, _optimize_checkout? = true) do
    [
      ~s[export GIT_LFS_SKIP_SMUDGE=1],
      ~s[export SEMAPHORE_GIT_PARTIAL_CLONE_FILTER="blob:none"],
      ~s[export SEMAPHORE_GIT_SPARSE_CHECKOUT_PATHS="#{sparse_checkout_path(req_args)}"]
    ] ++ checkout_and_compile_commands()
  end

  @doc false
  def default_commands(_req_args, _optimize_checkout? = false) do
    [~s[export GIT_LFS_SKIP_SMUDGE=1]] ++ checkout_and_compile_commands()
  end

  defp checkout_and_compile_commands() do
    [
      ~s[checkout],
      ~s[export INPUT_FILE="$SEMAPHORE_YAML_FILE_PATH"],
      ~s[export OUTPUT_FILE="${SEMAPHORE_YAML_FILE_PATH}.output.yml"],
      ~s[export LOGS_FILE="${SEMAPHORE_YAML_FILE_PATH}.logs.jsonl"],
      ~s[cat $INPUT_FILE],
      ~s[echo "Compiling $INPUT_FILE into $OUTPUT_FILE and storing logs to $LOGS_FILE"],
      ~s[spc compile --input $INPUT_FILE --output $OUTPUT_FILE --logs $LOGS_FILE]
    ]
  end

  # The pipeline lives in the working directory of the YAML file; sparse-checkout
  # of that directory keeps the pipeline files available while skipping the rest
  # of the repository. Falls back to the repository root when no working
  # directory is set (no optimization, but always correct).
  defp sparse_checkout_path(req_args) do
    case (req_args["working_dir"] || "") |> String.trim() do
      "" -> "."
      working_dir -> working_dir
    end
  end

  defp epilogue_always_commands() do
    [
      ~s[export BASE_NAME=$SEMAPHORE_PIPELINE_ID-$(basename $INPUT_FILE)],
      ~s[export ARTIFACT_LOG_DESTINATION="compilation/$BASE_NAME.logs"],
      ~s[echo "Uploading $LOGS_FILE into $ARTIFACT_LOG_DESTINATION"],
      ~s[artifact push workflow $LOGS_FILE   -d $ARTIFACT_LOG_DESTINATION],
      ~s[export ARTIFACT_YAML_DESTINATION="compilation/$BASE_NAME"],
      ~s[echo "Uploading $OUTPUT_FILE into $ARTIFACT_YAML_DESTINATION"],
      ~s[artifact push workflow $OUTPUT_FILE -d $ARTIFACT_YAML_DESTINATION]
    ]
  end

  defp sem_yaml_file_path_env_var(req_args) do
    working_dir = req_args["working_dir"] |> String.trim()
    file_name = req_args["file_name"] |> String.trim()
    path = "#{working_dir}/#{file_name}"

    %{"name" => "SEMAPHORE_YAML_FILE_PATH", "value" => path}
  end

  defp ppl_env_vars(ppl_req) do
    %{"build" => %{}}
    |> BlocksReviser.set_ppl_env_vars(%{"name" => ""}, ppl_req)
    |> extract_ppl_env_vars()
  end

  defp extract_ppl_env_vars({:ok, map}), do: get_in(map, ["build", "ppl_env_variables"])
  defp extract_ppl_env_vars(error), do: error

  defp test_commands(:stopping_test), do: ["sleep 3", "echo Test"]
  defp test_commands(_mix_env), do: ["echo Test"]
end
