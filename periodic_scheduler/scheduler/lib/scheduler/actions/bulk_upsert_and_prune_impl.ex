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

  alias Crontab.CronExpression.Parser
  alias Ecto.Multi
  alias Scheduler.DeleteRequests.Model.DeleteRequestsQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.Workers.QuantumScheduler
  alias Util.ToTuple

  @api_version "v1.2"

  def bulk_upsert_and_prune(params) do
    log_request(params)

    with {:org, true} <- {:org, present?(params[:organization_id])},
         {:project, true} <- {:project, present?(params[:project_id])},
         {:requester, true} <- {:requester, present?(params[:requester_id])},
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
      {:org, _} ->
        Logger.info("bulk_upsert_and_prune rejected: organization_id is empty")
        ToTuple.error("Organization ID is empty", :INVALID_ARGUMENT)

      {:project, _} ->
        Logger.info("bulk_upsert_and_prune rejected: project_id is empty")
        ToTuple.error("Project ID is empty", :INVALID_ARGUMENT)

      {:requester, _} ->
        Logger.info("bulk_upsert_and_prune rejected: requester_id is empty")
        ToTuple.error("Requester ID is empty", :INVALID_ARGUMENT)

      {:error, msg = "Project with ID" <> _rest} ->
        Logger.info(
          "bulk_upsert_and_prune rejected: project_id=#{params[:project_id]} not found in front DB"
        )

        ToTuple.error(msg, :FAILED_PRECONDITION)

      {:error, {:cron, name, msg}} ->
        Logger.info(
          "bulk_upsert_and_prune rejected: project_id=#{params[:project_id]} invalid cron " <>
            "for periodic '#{name}': #{inspect(msg)}"
        )

        ToTuple.error(format_cron_error(name, msg), :INVALID_ARGUMENT)

      {:error, {:tx, op, value, _changes}} ->
        Logger.info(
          "bulk_upsert_and_prune rolled back: project_id=#{params[:project_id]} " <>
            "failed_op=#{inspect(op)} value=#{inspect(value)}"
        )

        ToTuple.error(format_tx_error(value), :INVALID_ARGUMENT)

      {:error, msg} when is_binary(msg) ->
        Logger.info(
          "bulk_upsert_and_prune rejected: project_id=#{params[:project_id]} reason=#{msg}"
        )

        ToTuple.error(msg, :INVALID_ARGUMENT)

      error ->
        Logger.info(
          "bulk_upsert_and_prune rejected: project_id=#{params[:project_id]} " <>
            "unexpected=#{inspect(error)}"
        )

        ToTuple.error(error, :INVALID_ARGUMENT)
    end
  end

  defp log_request(params) do
    Logger.info(
      "bulk_upsert_and_prune received: project_id=#{params[:project_id]} " <>
        "organization_id=#{params[:organization_id]} requester_id=#{params[:requester_id]} " <>
        "periodics=#{length(normalize_periodics(params[:periodics]))}"
    )
  end

  defp present?(v) when is_binary(v) and v != "", do: true
  defp present?(_), do: false

  defp normalize_periodics(nil), do: []
  defp normalize_periodics(list) when is_list(list), do: list

  defp pre_validate(periodics) do
    Enum.reduce_while(periodics, :ok, fn periodic, _acc ->
      case validate_cron(periodic) do
        :ok -> {:cont, :ok}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp validate_cron(periodic) do
    if Map.get(periodic, :recurring, false) do
      parse_cron(Map.get(periodic, :at, ""), Map.get(periodic, :name, ""))
    else
      :ok
    end
  end

  defp parse_cron(expression, name) do
    case Wormhole.capture(Parser, :parse, [expression], skip_log: true, ok_tuple: true) do
      {:ok, _} -> :ok
      {:error, msg} -> {:error, {:cron, name, msg}}
    end
  end

  defp reconcile(params, project_name, periodics) do
    input_ids =
      periodics
      |> Enum.map(&Map.get(&1, :id))
      |> Enum.reject(&(&1 in [nil, ""]))

    prune_query =
      from(p in Periodics,
        where: p.project_id == ^params.project_id and p.id not in ^input_ids
      )

    multi =
      Multi.new()
      |> Multi.run(:prune_targets, fn _repo, _ -> {:ok, Repo.all(prune_query)} end)
      |> Multi.run(:audit_log, fn _repo, %{prune_targets: targets} ->
        insert_audit_rows(targets, params.requester_id)
      end)
      |> Multi.run(:prune, fn _repo, %{prune_targets: targets} ->
        ids = Enum.map(targets, & &1.id)

        {n, _} =
          from(p in Periodics,
            where: p.project_id == ^params.project_id and p.id in ^ids
          )
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
    case lookup(Map.get(definition, :id)) do
      :create ->
        PeriodicsQueries.insert(
          build_create_params(definition, params, project_name),
          @api_version
        )

      {:ok, periodic} ->
        PeriodicsQueries.update(periodic, build_update_params(definition, params), @api_version)

      {:error, "Periodic with id:" <> _} ->
        PeriodicsQueries.insert(
          build_create_params(definition, params, project_name),
          @api_version
        )
    end
  end

  defp lookup(nil), do: :create
  defp lookup(""), do: :create
  defp lookup(id), do: PeriodicsQueries.get_by_id(id)

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
      organization_id: params.organization_id,
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
