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
      case apply_side_effects(upserts, pruned) do
        [] ->
          log_summary(params, upserts, pruned)

          {:ok,
           %{
             upserted: Enum.map(upserts, &to_response_map/1),
             deleted_ids: Enum.map(pruned, & &1.id)
           }}

        failures ->
          report_side_effect_failures(params, failures)
          ToTuple.error(format_side_effect_failures(failures), :INTERNAL)
      end
    else
      {:error, msg = "Project with ID" <> _rest} ->
        ToTuple.error(msg, :FAILED_PRECONDITION)

      {:error, {:cron, name, msg}} ->
        ToTuple.error(format_cron_error(name, msg), :INVALID_ARGUMENT)

      {:error, {:field, idx, field, msg}} ->
        ToTuple.error("Periodic at index #{idx}: '#{field}' #{msg}.", :INVALID_ARGUMENT)

      {:error, {:tx, {:upsert, _idx}, {:foreign_id, id}, _changes}} ->
        ToTuple.error("Periodic task with ID '#{id}' not found in project", :NOT_FOUND)

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
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {definition, idx}, _acc ->
      case validate_definition(definition, idx) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_definition(definition, idx) do
    cond do
      blank?(Map.get(definition, :name)) ->
        {:error, {:field, idx, :name, "must be a non-empty string"}}

      blank?(Map.get(definition, :reference)) ->
        {:error, {:field, idx, :reference, "must be a non-empty string"}}

      blank?(Map.get(definition, :pipeline_file)) ->
        {:error, {:field, idx, :pipeline_file, "must be a non-empty string"}}

      Map.get(definition, :recurring, false) ->
        case CronValidator.parse(Map.get(definition, :at, "")) do
          {:ok, _} -> :ok
          {:error, msg} -> {:error, {:cron, Map.get(definition, :name, ""), msg}}
        end

      true ->
        :ok
    end
  end

  defp blank?(v), do: not (is_binary(v) and v != "")

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

      {:error, {:foreign_id, _id}} = error ->
        error
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
      audit_params = %{
        id: target.id,
        periodic_name: target.name,
        organization_id: target.organization_id,
        requester: requester_id
      }

      case DeleteRequestsQueries.insert(audit_params) do
        {:ok, row} -> {:cont, {:ok, [row | acc]}}
        error -> {:halt, error}
      end
    end)
  end

  defp apply_side_effects(upserts, pruned) do
    upsert_failures = run_side_effects(upserts, &start_or_stop_periodic_job/1, :upsert)
    prune_failures = run_side_effects(pruned, &prune_quantum_job/1, :prune)
    upsert_failures ++ prune_failures
  end

  defp run_side_effects(items, fun, kind) do
    Enum.reduce(items, [], fn item, acc ->
      try do
        case fun.(item) do
          {:ok, _} -> acc
          :ok -> acc
          {:error, reason} -> [{kind, item.id, reason} | acc]
          other -> [{kind, item.id, {:unexpected, other}} | acc]
        end
      rescue
        e -> [{kind, item.id, e} | acc]
      catch
        kind_caught, value -> [{kind, item.id, {kind_caught, value}} | acc]
      end
    end)
  end

  defp prune_quantum_job(periodic), do: delete_quantum_job(periodic.id)

  defp report_side_effect_failures(params, failures) do
    Enum.each(failures, fn {kind, id, reason} ->
      Logger.error(
        "bulk_upsert_and_prune side-effect failure: kind=#{kind} " <>
          "periodic_id=#{id} project_id=#{params.project_id} " <>
          "requester_id=#{params.requester_id} reason=#{inspect(reason)}"
      )

      Watchman.increment({"PeriodicSch.bulk_upsert_and_prune.quantum_failure", [to_string(kind)]})
    end)
  end

  defp format_side_effect_failures(failures) do
    ids = failures |> Enum.map(fn {_, id, _} -> id end) |> Enum.uniq()

    "Schedule registration failed for #{length(failures)} periodic(s): #{Enum.join(ids, ", ")}"
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

  defp start_periodic_job(periodic), do: quantum_scheduler().start_periodic_job(periodic)

  defp stop_periodic_job(periodic) do
    case delete_quantum_job(periodic.id) do
      :ok -> {:ok, :stopped}
      {:ok, _} -> {:ok, :stopped}
      other -> other
    end
  end

  defp delete_quantum_job(id), do: id |> String.to_atom() |> quantum_scheduler().delete_job()

  defp quantum_scheduler do
    Application.get_env(:scheduler, :quantum_scheduler, QuantumScheduler)
  end

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
