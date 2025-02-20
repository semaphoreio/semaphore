defmodule Ppl.PplTraces.Model.PplTracesQueries do
  @moduledoc """
  Pipeline Trace Queries
  Operations on Pipeline Traces  type
  """

  import Ecto.Query

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.PplTraces.Model.PplTraces

  def insert(ppl) do
    params = %{ppl_id: ppl.ppl_id, created_at: ppl.inserted_at}

    %PplTraces{} |> PplTraces.changeset_insert(params) |> Repo.insert
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  @valid_timestamps ~w(pending_at queuing_at running_at stopping_at done_at)a

  def set_timestamp(ppl_id, timestamp_name) when timestamp_name in @valid_timestamps do
    PplTraces
    |> where(ppl_id: ^ppl_id)
    |> update(set: ^set_value(timestamp_name))
    |> select([s], s)
    |> Repo.update_all([])
    |> set_timestamp_success?
  end
  def set_timestamp(_ppl_id, field),
    do: {:error, "Unsuported field in PipelineTrace model: #{field}"}

  defp set_value(timestamp_name) do
    Keyword.new |> Keyword.put(timestamp_name, DateTime.utc_now())
  end

  # It has to be exactly 1 item
  defp set_timestamp_success?({1, [item]}), do: {:ok, item}
  defp set_timestamp_success?(resp), do: {:error, resp}

  def get_by_id(id) do
      PplTraces |> where(ppl_id: ^id) |> Repo.one()
      |> return_tuple("Pipeline Trace with id: #{id} not found")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
