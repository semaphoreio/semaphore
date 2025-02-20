defmodule Scheduler.Actions.PersistImpl do
  @moduledoc """
  Module serves to either create or update periodic with params given in request
  and then start quantum job for that periodic.
  """

  alias Util.ToTuple
  alias Scheduler.Periodics.Model.PeriodicsQueries
  alias Scheduler.FrontDB.Model.FrontDBQueries
  alias Crontab.CronExpression.Parser
  alias Scheduler.Workers.QuantumScheduler

  def persist(request) do
    with {:cron, {:ok, _}} <- validate_cron_expression(request),
         found? <- PeriodicsQueries.get_by_id(request.id),
         {:ok, periodic_id} <- create_or_update(found?, request),
         {:ok, periodic} <- PeriodicsQueries.get_by_id(periodic_id) do
      parameters = Enum.into(periodic.parameters, [], &Map.from_struct/1)
      {:ok, periodic |> Map.from_struct() |> Map.put(:parameters, parameters)}
    else
      {:error, msg = "Project with ID" <> _rest} ->
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

  defp validate_cron_expression(request) do
    if request.recurring do
      {:cron, Wormhole.capture(Parser, :parse, [request.at], skip_log: true, ok_tuple: true)}
    else
      {:cron, {:ok, %Crontab.CronExpression{}}}
    end
  end

  defp create_or_update({:error, "Periodic with id:" <> _}, request),
    do: create(request)

  defp create_or_update({:ok, periodic}, request),
    do: update(periodic, request)

  defp create(request) do
    with {:ok, project_name} <- get_project_name(request.organization_id, request.project_id),
         {:ok, params} <- form_periodic_params(request, project_name),
         {:ok, periodic} <- PeriodicsQueries.insert(params, "v1.1"),
         {:ok, _job} <- start_periodic_job(periodic) do
      {:ok, periodic.id}
    end
  end

  defp update(periodic, request) do
    with {:ok, params} <- form_periodic_params(request, periodic),
         {:ok, periodic} <- PeriodicsQueries.update(periodic, params, "v1.1"),
         {:ok, _job} <- start_or_stop_periodic_job(periodic) do
      {:ok, periodic.id}
    end
  end

  defp get_project_name(nil, _project_id), do: {:error, "Organization ID is empty"}
  defp get_project_name("", _project_id), do: {:error, "Organization ID is empty"}
  defp get_project_name(_org_id, nil), do: {:error, "Project ID is empty"}
  defp get_project_name(_org_id, ""), do: {:error, "Project ID is empty"}

  defp get_project_name(org_id, project_id) do
    case FrontDBQueries.get_project_name(org_id, project_id) do
      {:ok, project_name} -> {:ok, project_name}
      {:error, msg} -> {:error, msg}
    end
  end

  defp form_periodic_params(request, project_name) when is_binary(project_name) do
    parameters = Enum.into(request.parameters, [], &convert_parameter_to_map/1)

    request
    |> Map.take(~w(
      name description recurring
      organization_id project_id requester_id
      branch pipeline_file at
    )a)
    |> Map.put(:parameters, parameters)
    |> inject_paused(request.state)
    |> Map.put(:project_name, project_name)
    |> ToTuple.ok()
  end

  defp form_periodic_params(request, periodic) when is_struct(periodic) do
    parameters = Enum.into(request.parameters, [], &convert_parameter_to_map/1)

    request
    |> Map.take(~w(
      name description recurring requester_id
      branch pipeline_file at
    )a)
    |> inject_paused(request.state)
    |> Map.put(:parameters, parameters)
    |> ToTuple.ok()
  end

  defp inject_paused(params, :UNCHANGED), do: params

  defp inject_paused(params, :ACTIVE),
    do:
      Map.merge(params, %{
        paused: false,
        pause_toggled_by: params[:requester_id],
        pause_toggled_at: DateTime.utc_now()
      })

  defp inject_paused(params, :PAUSED),
    do:
      Map.merge(params, %{
        paused: true,
        pause_toggled_by: params[:requester_id],
        pause_toggled_at: DateTime.utc_now()
      })

  defp convert_parameter_to_map(parameter) do
    parameter |> Map.take(~w(name required description default_value options)a)
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
end
