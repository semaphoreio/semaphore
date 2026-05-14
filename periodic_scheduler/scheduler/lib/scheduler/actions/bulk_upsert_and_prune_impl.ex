defmodule Scheduler.Actions.BulkUpsertAndPruneImpl do
  @moduledoc """
  Transactionally reconciles the set of periodic tasks for a single project.

  Given a project_id and a desired list of periodic definitions, this action:

    * upserts each definition (insert if id is empty / unknown, update if id
      matches an existing periodic)
    * deletes any other periodic on the same project (i.e. ids not present in
      the desired set)

  All database mutations run inside a single `Ecto.Multi` transaction, so the
  caller is guaranteed an all-or-nothing outcome. Quantum scheduler side effects
  (registering / unregistering cron jobs) run after the transaction commits and
  are idempotent.
  """

  require Logger
  import Ecto.Query

  alias Ecto.Multi
  alias Scheduler.Actions.CronValidator
  alias Scheduler.DeleteRequests.Model.DeleteRequestsQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.Workers.QuantumScheduler
  alias Util.ToTuple

  @api_version "v1.2"

  def bulk_upsert_and_prune(params) do
    with :ok <- validate_presence(params),
         {:ok, project_name} <-
           FrontDBQueries.get_project_name(params.organization_id, params.project_id),
         periodics <- normalize_periodics(params[:periodics]),
         :ok <- pre_validate(periodics),
         {:ok, %{upserts: upserts, pruned: pruned}} <- reconcile(params, project_name, periodics) do
      apply_side_effects(upserts, pruned)
      log_summary(params, upserts, pruned)

      {:ok,
       %{upserted: Enum.map(upserts, &to_response_map/1), deleted_ids: Enum.map(pruned, & &1.id)}}
    else
      {:error, msg = "Project with ID" <> _rest} ->
        ToTuple.error(msg, :FAILED_PRECONDITION)

      {:error, {:cron, name, msg}} ->
        ToTuple.error(format_cron_error(name, msg), :INVALID_ARGUMENT)

      {:error, {:tx, _op, value, _changes}} ->
        ToTuple.error(format_tx_error(value), :INVALID_ARGUMENT)

      {:error, msg} when is_binary(msg) ->
        ToTuple.error(msg, :INVALID_ARGUMENT)

      error ->
        ToTuple.error(error, :INVALID_ARGUMENT)
    end
  end

  defp validate_presence(params) do
    cond do
      not present?(params[:organization_id]) -> {:error, "Organization ID is empty"}
      not present?(params[:project_id]) -> {:error, "Project ID is empty"}
      not present?(params[:requester_id]) -> {:error, "Requester ID is empty"}
      true -> :ok
    end
  end

  defp present?(v) when is_binary(v) and v != "", do: true
  defp present?(_), do: false

  defp normalize_periodics(list), do: List.wrap(list)

  defp pre_validate(periodics) do
    periodics
    |> Enum.filter(&Map.get(&1, :recurring, false))
    |> Enum.find_value(:ok, fn periodic ->
      case CronValidator.parse(Map.get(periodic, :at, "")) do
        {:ok, _} -> nil
        {:error, msg} -> {:error, {:cron, Map.get(periodic, :name, ""), msg}}
      end
    end)
  end

  defp reconcile(params, project_name, periodics) do
    input_ids =
      periodics
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.reject(&(&1 in [nil, ""]))

    prune_query =
      Periodics
      |> where([p], p.project_id == ^params.project_id and p.id not in ^input_ids)

    multi =
      Multi.new()
      |> Multi.run(:prune_targets, fn _repo, _ -> {:ok, Repo.all(prune_query)} end)
      |> Multi.run(:audit_log, fn _repo, %{prune_targets: targets} ->
        insert_audit_rows(targets, params.requester_id)
      end)
      |> Multi.run(:prune, fn _repo, %{prune_targets: targets} ->
        ids = Enum.map(targets, & &1.id)

        {n, _} =
          Periodics
          |> where([p], p.project_id == ^params.project_id and p.id in ^ids)
          |> Repo.delete_all()

        {:ok, n}
      end)

    multi =
      periodics
      |> Enum.with_index()
      |> Enum.reduce(multi, fn {definition, idx}, m ->
        Multi.run(m, {:upsert, idx}, fn _repo, _ ->
          upsert_one(definition, params, project_name)
        end)
      end)

    case Repo.transaction(multi) do
      {:ok, changes} ->
        upserts =
          changes
          |> Enum.filter(fn {key, _} -> match?({:upsert, _}, key) end)
          |> Enum.sort_by(fn {{:upsert, idx}, _} -> idx end)
          |> Enum.map(fn {_, value} -> value end)
          |> Enum.reject(&(&1 == :skipped))

        {:ok, %{upserts: upserts, pruned: changes.prune_targets}}

      {:error, failed_op, failed_value, changes} ->
        {:error, {:tx, failed_op, failed_value, changes}}
    end
  end

  defp upsert_one(definition, params, project_name) do
    case lookup(params.project_id, Map.get(definition, :id)) do
      :create ->
        PeriodicsQueries.insert(
          build_create_params(definition, params, project_name),
          @api_version
        )

      {:ok, periodic} ->
        PeriodicsQueries.update(periodic, build_update_params(definition, params), @api_version)

      {:error, {:foreign_id, _id}} ->
        {:ok, :skipped}
    end
  end

  defp lookup(_project_id, nil), do: :create
  defp lookup(_project_id, ""), do: :create

  defp lookup(project_id, id) do
    case Repo.get_by(Periodics, id: id, project_id: project_id) do
      nil -> {:error, {:foreign_id, id}}
      periodic -> {:ok, periodic}
    end
  end

  defp build_create_params(definition, params, project_name) do
    %{
      name: Map.get(definition, :name, ""),
      description: Map.get(definition, :description, ""),
      recurring: Map.get(definition, :recurring, false),
      organization_id: params.organization_id,
      project_id: params.project_id,
      project_name: project_name,
      requester_id: params.requester_id,
      reference: Map.get(definition, :reference, ""),
      pipeline_file: Map.get(definition, :pipeline_file, ""),
      at: Map.get(definition, :at, ""),
      parameters: convert_parameters(Map.get(definition, :parameters, []))
    }
    |> inject_paused(Map.get(definition, :state, :UNCHANGED), params.requester_id)
  end

  defp build_update_params(definition, params) do
    %{
      name: Map.get(definition, :name),
      description: Map.get(definition, :description, ""),
      recurring: Map.get(definition, :recurring, false),
      requester_id: params.requester_id,
      reference: Map.get(definition, :reference, ""),
      pipeline_file: Map.get(definition, :pipeline_file, ""),
      at: Map.get(definition, :at, ""),
      parameters: convert_parameters(Map.get(definition, :parameters, []))
    }
    |> inject_paused(Map.get(definition, :state, :UNCHANGED), params.requester_id)
  end

  defp inject_paused(params, :UNCHANGED, _requester_id), do: params

  defp inject_paused(params, :ACTIVE, requester_id) do
    Map.merge(params, %{
      paused: false,
      pause_toggled_by: requester_id,
      pause_toggled_at: DateTime.utc_now()
    })
  end

  defp inject_paused(params, :PAUSED, requester_id) do
    Map.merge(params, %{
      paused: true,
      pause_toggled_by: requester_id,
      pause_toggled_at: DateTime.utc_now()
    })
  end

  defp inject_paused(params, _state, _requester_id), do: params

  defp convert_parameters(parameters) do
    Enum.map(parameters, fn parameter ->
      Map.take(
        parameter,
        ~w(name required description default_value options regex_pattern validate_input_format)a
      )
    end)
  end

  defp insert_audit_rows(targets, requester_id) do
    Enum.reduce_while(targets, {:ok, []}, fn target, {:ok, acc} ->
      case DeleteRequestsQueries.insert(%{id: target.id, requester: requester_id}) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_side_effects(upserts, pruned) do
    Enum.each(upserts, &start_or_stop_periodic_job/1)
    Enum.each(pruned, fn periodic -> delete_quantum_job(periodic.id) end)
    :ok
  end

  defp log_summary(params, upserts, pruned) do
    Logger.info(
      "bulk_upsert_and_prune committed: project_id=#{params.project_id} " <>
        "requester_id=#{params.requester_id} upserted=#{length(upserts)} pruned=#{length(pruned)}"
    )
  end

  defp start_or_stop_periodic_job(periodic = %{paused: true}), do: stop_periodic_job(periodic)
  defp start_or_stop_periodic_job(periodic = %{recurring: false}), do: stop_periodic_job(periodic)
  defp start_or_stop_periodic_job(periodic), do: start_periodic_job(periodic)

  defp start_periodic_job(%{suspended: suspended, paused: paused, recurring: recurring})
       when suspended or paused or not recurring,
       do: {:ok, :skip}

  defp start_periodic_job(periodic), do: QuantumScheduler.start_periodic_job(periodic)

  defp stop_periodic_job(periodic) do
    delete_quantum_job(periodic.id)
    {:ok, :stopped}
  end

  defp delete_quantum_job(id), do: id |> String.to_atom() |> QuantumScheduler.delete_job()

  defp to_response_map(periodic) do
    parameters = Enum.into(periodic.parameters, [], &Map.from_struct/1)
    periodic |> Map.from_struct() |> Map.put(:parameters, parameters)
  end

  defp format_cron_error(name, msg) do
    "Invalid cron expression in 'at' field for periodic '#{name}': #{inspect(msg)}"
  end

  defp format_tx_error(value) when is_binary(value), do: value
  defp format_tx_error(value), do: inspect(value)
end
