defmodule Scheduler.PeriodicsTriggers.Model.PeriodicsTriggersQueries do
  @moduledoc """
  PeriodicsTriggers Queries
  Operations on PeriodicsTriggers type
  """

  import Ecto.Query

  alias Scheduler.PeriodicsRepo, as: Repo
  alias Scheduler.Periodics.Model.Periodics
  alias Scheduler.PeriodicsTriggers.Model.PeriodicsTriggers
  alias Scheduler.Utils.GitReference
  alias LogTee, as: LT
  alias Util.ToTuple

  @doc """
  Gets PeriodicsTrigger by id
  """
  def get_by_id(nil), do: {:error, "Periodic trigger id is nil."}

  def get_by_id(id) do
    PeriodicsTriggers
    |> Repo.get(id)
    |> case do
      nil -> {:error, "Periodic trigger with id #{id} not found."}
      trigger -> trigger |> ToTuple.ok()
    end
  end

  @doc """
  Inserts new PeriodicsTrigger for given periodic
  """

  def insert(periodic, params \\ %{}) do
    default_params = %{
      periodic_id: periodic.id,
      triggered_at: DateTime.utc_now(),
      project_id: periodic.project_id,
      recurring: periodic.recurring,
      reference: periodic.reference,
      pipeline_file: periodic.pipeline_file,
      parameter_values: Periodics.default_parameter_values(periodic),
      scheduling_status: "running",
      run_now_requester_id: params[:requester]
    }

    merged_params = default_params |> Map.merge(params)

    # Normalize reference field to ensure consistent format
    normalized_params =
      case merged_params.reference do
        ref when is_binary(ref) ->
          Map.put(merged_params, :reference, GitReference.normalize(ref))

        _ ->
          merged_params
      end

    insert_(normalized_params)
  end

  defp insert_(params) do
    %PeriodicsTriggers{}
    |> PeriodicsTriggers.changeset_insert(params)
    |> Repo.insert()
    |> LT.info("persisted periodic_trigger: #{params.periodic_id}")
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Updates PeriodicsTrigger record with scheduling results
  """
  def update(trigger, params) do
    params = params |> Map.put(:scheduled_at, DateTime.utc_now())

    trigger
    |> PeriodicsTriggers.changeset_update(params)
    |> Repo.update()
    |> LT.info("updated periodic_trigger: #{trigger.periodic_id}")
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @doc """
  Returns one latest PeriodicsTrigger for each periodic with id in the given list
  """
  def get_latest_triggers(periodic_ids) do
    """
    #{get_latest_triggers_sql(periodic_ids)}
    """
    |> Repo.query([])
    |> to_maps()
  end

  defp get_latest_triggers_sql(periodic_ids) do
    """
      SELECT t.*
      FROM   periodics p
      CROSS  JOIN LATERAL (
        SELECT t.*
        FROM   periodics_triggers t
        WHERE  t.periodic_id = p.id  -- lateral reference
        ORDER  BY t.triggered_at DESC NULLS LAST
        LIMIT 1
      ) t
      WHERE p.id IN (#{list_to_comma_separated_string(periodic_ids)});
    """
  end

  defp list_to_comma_separated_string(ids) do
    Enum.map_join(ids, ", ", fn id -> "'#{id}'" end)
  end

  defp to_maps({:ok, %{columns: columns, rows: rows}}) do
    rows
    |> Enum.map(fn row ->
      columns |> Enum.zip(row) |> Enum.into(%{}) |> to_date_time() |> uuid_to_string()
    end)
    |> ToTuple.ok()
  end

  defp to_maps(error), do: error

  defp to_date_time(map) when is_map(map) do
    map
    |> Map.take(["triggered_at", "scheduled_at", "inserted_at", "updated_at"])
    |> Enum.reduce(map, fn {field, ts_tuple}, result ->
      unix_ts = ts_tuple |> Timex.to_datetime() |> to_unix_dt()

      timestamp =
        if is_integer(unix_ts) do
          %{
            "seconds" => Kernel.trunc(unix_ts / 1_000_000),
            "nanos" => Kernel.rem(unix_ts, 1_000_000) * 1_000
          }
        else
          %{"seconds" => 0, "nanos" => 0}
        end

      result |> Map.put(field, timestamp)
    end)
  end

  defp to_date_time(error), do: error

  defp to_unix_dt({:error, term}) do
    term |> LT.debug("Periodics trigger time format: ")
    0
  end

  defp to_unix_dt(t) do
    DateTime.to_unix(t, :microsecond)
  end

  defp uuid_to_string(map) when is_map(map) do
    id = map |> Map.get("periodic_id") |> UUID.binary_to_string!()
    Map.put(map, "periodic_id", id)
  end

  @doc """
  Returns last n PeriodicsTriggers of the periodic with the given id.
  """
  def get_n_by_periodic_id(id, n) do
    PeriodicsTriggers
    |> where([pt], pt.periodic_id == ^id)
    |> order_by([pt], desc: pt.triggered_at)
    |> limit(^n)
    |> Repo.all([])
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  @doc """
  Finds all PeriodicsTriggers for periodic with given id
  """
  def get_all_by_periodic_id(id) do
    PeriodicsTriggers
    |> where([pt], pt.periodic_id == ^id)
    |> order_by([pt], desc: pt.triggered_at)
    |> Repo.all([])
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end
end
