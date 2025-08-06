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
    [
      %{
        "name" => "Compilation",
        "execution_time_limit" => %{"minutes" => @default_execution_limit_in_minutes},
        "priority" => [%{"value" => @default_priority, "when" => true}],
        "env_vars" => ppl_env_vars(ppl_req) ++ [sem_yaml_file_path_env_var(req_args)],
        "secrets" => secrets_definition(pfcs, req_args),
        "commands" => commands(pfcs),
        "epilogue_always_cmds" => epilogue_always_commands()
      }
    ]
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

  defp commands(pfcs) do
    default_commands() ++ pfc_commands(pfcs)
  end

  defp pfc_commands(%{"organization_pfc" => org_pfc, "project_pfc" => prj_pfc})
       when is_map(org_pfc) and is_map(prj_pfc),
       do: Map.get(org_pfc, "commands", []) ++ Map.get(prj_pfc, "commands", [])

  defp pfc_commands(%{"organization_pfc" => org_pfc}) when is_map(org_pfc),
    do: Map.get(org_pfc, "commands", [])

  defp pfc_commands(%{"project_pfc" => prj_pfc}) when is_map(prj_pfc),
    do: Map.get(prj_pfc, "commands", [])

  defp pfc_commands(_ppl_req), do: []

  defp default_commands() do
    [
      ~s[export GIT_LFS_SKIP_SMUDGE=1],
      ~s[checkout],
      ~s[export INPUT_FILE="$SEMAPHORE_YAML_FILE_PATH"],
      ~s[export OUTPUT_FILE="${SEMAPHORE_YAML_FILE_PATH}.output.yml"],
      ~s[export LOGS_FILE="${SEMAPHORE_YAML_FILE_PATH}.logs.jsonl"],
      ~s[cat $INPUT_FILE],
      ~s[echo "Compiling $INPUT_FILE into $OUTPUT_FILE and storing logs to $LOGS_FILE"],
      ~s[spc compile --input $INPUT_FILE --output $OUTPUT_FILE --logs $LOGS_FILE]
    ]
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
    |> BlocksReviser.set_ppl_env_vars(ppl_req)
    |> extract_ppl_env_vars()
  end

  defp extract_ppl_env_vars({:ok, map}), do: get_in(map, ["build", "ppl_env_variables"])
  defp extract_ppl_env_vars(error), do: error

  defp test_commands(:stopping_test), do: ["sleep 3", "echo Test"]
  defp test_commands(_mix_env), do: ["echo Test"]
end
