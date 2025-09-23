defmodule Scheduler.Actions.ApplyImpl do
  @moduledoc """
  Module serves to either create or update periodic with params given in request
  and then start quantum job for that periodic.
  """

  alias Util.ToTuple
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Crontab.CronExpression.Parser
  alias Scheduler.Workers.QuantumScheduler
  alias Scheduler.Utils.GitReference

  def apply(request) do
    with {:ok, definition} <- DefinitionValidator.validate_yaml_string(request.yml_definition),
         {:cron, {:ok, _}} <- validate_cron_expression(definition),
         {:ok, project_id} <- find_project_id(request, definition),
         {:hook, {:ok, true}} <- hook_exists?(project_id, request.organization_id, definition),
         found? <- find_periodic(definition),
         {:ok, periodic_id} <- create_or_update(found?, request, definition, project_id) do
      {:ok, periodic_id}
    else
      {:hook, _} ->
        "At least one regular workflow run on targeted branch is needed before periodic can be created."
        |> ToTuple.error(:FAILED_PRECONDITION)

      {:error, msg = "Project with name" <> _rest} ->
        ToTuple.error(msg, :FAILED_PRECONDITION)

      {:cron, {:error, msg}} ->
        "Invalid cron expression in 'at' field: #{inspect(msg)}"
        |> ToTuple.error(:INVALID_ARGUMENT)

      {:error, msg} ->
        msg |> ToTuple.error(:INVALID_ARGUMENT)

      error ->
        error |> ToTuple.error(:INVALID_ARGUMENT)
    end
  end

  defp validate_cron_expression(definition) do
    api_version = definition |> Map.get("apiVersion", "")
    validate_cron_expression(definition, api_version)
  end

  defp validate_cron_expression(definition, "v1.1") do
    recurring = definition |> Map.get("spec", %{}) |> Map.get("recurring", true)
    cron_exp = definition |> Map.get("spec", %{}) |> Map.get("at", "")

    if recurring,
      do: {:cron, Wormhole.capture(Parser, :parse, [cron_exp], skip_log: true, ok_tuple: true)},
      else: {:cron, {:ok, %Crontab.CronExpression{}}}
  end

  defp validate_cron_expression(definition, "v1.2"),
    do: validate_cron_expression(definition, "v1.1")

  defp validate_cron_expression(definition, _version_1_0) do
    cron_exp = definition |> Map.get("spec", %{}) |> Map.get("at", "")

    case Wormhole.capture(Parser, :parse, [cron_exp], skip_log: true, ok_tuple: true) do
      result -> {:cron, result}
    end
  end

  defp find_project_id(request, definition) do
    project_name = definition |> Map.get("spec", %{}) |> Map.get("project", "")
    FrontDBQueries.get_project_id(request.organization_id, project_name)
  end

  defp hook_exists?(project_id, org_id, definition) do
    scheduler_hook_enabled? = FeatureProvider.feature_enabled?(:scheduler_hook, param: org_id)
    just_run_enabled? = FeatureProvider.feature_enabled?(:just_run, param: org_id)

    if scheduler_hook_enabled? or just_run_enabled? do
      {:hook, {:ok, true}}
    else
      recurring = definition |> Map.get("spec", %{}) |> Map.get("recurring", true)
      branch = extract_branch_name(definition)

      if recurring,
        do: {:hook, FrontDBQueries.hook_exists?(project_id, branch)},
        else: {:hook, {:ok, true}}
    end
  end

  defp find_periodic(definition) do
    id = definition |> Map.get("metadata", %{}) |> Map.get("id", "")
    PeriodicsQueries.get_by_id(id)
  end

  defp create_or_update({:error, "Periodic with id:" <> _}, request, definition, project_id),
    do: create(request, definition, project_id)

  defp create_or_update({:ok, periodic}, request, definition, project_id),
    do: update(periodic, request, definition, project_id)

  defp create(request, definition, project_id) do
    api_version = definition |> Map.get("apiVersion", "")

    with {:ok, params} <- form_periodic_params(request, definition, project_id),
         {:ok, periodic} <- PeriodicsQueries.insert(params, api_version),
         {:ok, _job} <- start_periodic_job(periodic) do
      {:ok, periodic.id}
    end
  end

  defp update(periodic, request, definition, project_id) do
    api_version = definition |> Map.get("apiVersion", "")

    with {:ok, params} <- form_periodic_params(request, definition, project_id, periodic),
         {:ok, periodic} <- PeriodicsQueries.update(periodic, params, api_version),
         {:ok, _job} <- start_or_stop_periodic_job(periodic) do
      {:ok, periodic.id}
    end
  end

  defp start_or_stop_periodic_job(periodic = %{paused: true}) do
    stop_periodic_job(periodic)
  end

  defp start_or_stop_periodic_job(periodic = %{recurring: false}) do
    stop_periodic_job(periodic)
  end

  defp start_or_stop_periodic_job(periodic) do
    start_periodic_job(periodic)
  end

  defp start_periodic_job(%{suspended: suspended, paused: paused, recurring: recurring})
       when suspended or paused or not recurring,
       do: {:ok, :skip}

  defp start_periodic_job(periodic) do
    QuantumScheduler.start_periodic_job(periodic)
  end

  defp stop_periodic_job(periodic) do
    periodic.id |> String.to_atom() |> QuantumScheduler.delete_job()
    {:ok, :stopped}
  end

  defp form_periodic_params(request, definition, project_id, original_periodic \\ %{}) do
    api_version = definition |> Map.get("apiVersion", "")

    definition
    |> transform_keys()
    |> extract_spec()
    |> extract_metadata()
    |> handle_reference_field_mapping(api_version, definition)
    |> Map.merge(request)
    |> consolidate_paused(original_periodic)
    |> Map.merge(%{project_id: project_id})
    |> ToTuple.ok()
  end

  defp transform_keys(map) when is_map(map) do
    map
    |> Enum.into(%{}, fn {key, val} ->
      {key |> rename() |> String.to_atom(), transform_keys(val)}
    end)
  end

  defp transform_keys(list) when is_list(list) do
    list |> Enum.map(fn val -> transform_keys(val) end)
  end

  defp transform_keys(val), do: val

  defp rename("project"), do: "project_name"
  defp rename(val), do: val

  defp extract_spec(map = %{spec: spec}) do
    map |> Map.delete(:spec) |> Map.merge(spec)
  end

  defp extract_metadata(map = %{metadata: metadata}) do
    map |> Map.delete(:metadata) |> Map.merge(metadata)
  end

  defp consolidate_paused(params = %{paused: true}, original_periodic)
       when original_periodic == %{} do
    params
    |> Map.merge(%{pause_toggled_by: params.requester_id, pause_toggled_at: DateTime.utc_now()})
  end

  defp consolidate_paused(params, original_periodic) when original_periodic == %{} do
    params
  end

  defp consolidate_paused(params = %{paused: updated}, %{paused: current})
       when updated == current do
    params
  end

  defp consolidate_paused(params = %{paused: _}, _) do
    params
    |> Map.merge(%{pause_toggled_by: params.requester_id, pause_toggled_at: DateTime.utc_now()})
  end

  defp consolidate_paused(params, _), do: params

  # Handle mapping between API versions and database field
  defp handle_reference_field_mapping(params, api_version, original_definition) do
    cond do
      # v1.1 and earlier use 'branch' field - map it to 'reference' for database
      api_version in ["v1.0", "v1.1"] ->
        branch_name = extract_branch_name(original_definition)

        params
        |> Map.delete(:branch)
        |> Map.put(:reference, branch_name)

      # v1.2 uses 'reference' object - extract the name
      api_version == "v1.2" ->
        reference_name = extract_reference_name(original_definition)

        params
        |> Map.delete(:reference)
        |> Map.put(:reference, reference_name)

      # Default case
      true ->
        params
    end
  end

  # Extract branch name for v1.1 and earlier, or from v1.2 reference object
  defp extract_branch_name(definition) do
    api_version = definition |> Map.get("apiVersion", "")
    spec = definition |> Map.get("spec", %{})

    case api_version do
      "v1.2" ->
        case spec |> Map.get("reference") do
          reference when is_map(reference) ->
            reference |> Map.get("name", "")

          _not_a_map ->
            spec |> Map.get("branch", "")
        end

      _other ->
        spec |> Map.get("branch", "")
    end
  end

  # Extract and build full reference path from v1.2 reference object or branch field
  defp extract_reference_name(definition) do
    spec = definition |> Map.get("spec", %{})

    case spec |> Map.get("reference") do
      reference when is_map(reference) ->
        type = reference |> Map.get("type", "")
        name = reference |> Map.get("name", "")
        build_full_reference(type, name)

      _not_a_map ->
        # Fallback to branch field for backwards compatibility in v1.2
        branch_name = spec |> Map.get("branch", "")
        build_full_reference("BRANCH", branch_name)
    end
  end

  # Build full reference path based on type
  defp build_full_reference(type, name), do: GitReference.build_full_reference(type, name)
end
