defmodule Gofer.Switch.Model.SwitchQueries do
  @moduledoc """
  Queries on Switch type
  """
  import Ecto.Query

  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo, as: Repo
  alias LogTee, as: LT
  alias Util.ToTuple

  def insert(params) do
    ppl_id = Map.get(params, "ppl_id")
    id = Map.get(params, "id")

    try do
      %Switch{}
      |> Switch.changeset(params)
      |> Repo.insert()
      |> process_response(ppl_id, id)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp process_response({:error, %Ecto.Changeset{errors: [switches_pkey: _message]}}, _ppl_id, id) do
    {:error, {:switch_id_exists, id}}
  end

  defp process_response(
         {:error, %Ecto.Changeset{errors: [unique_ppl_id_for_switch: _message]}},
         ppl_id,
         _id
       ) do
    ppl_id
    |> LT.info("SwitchQueries.insert() - There is already switch with given ppl_id: ")

    {:error, {:ppl_id_exists, ppl_id}}
  end

  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _, _) do
    {:error, Map.put(%{}, key, message)}
  end

  defp process_response({:ok, switch}, ppl_id, _id) do
    switch
    |> LT.info("Persisted switch with ppl_id: #{ppl_id}")
    |> ToTuple.ok()
  end

  def update(switch, params) do
    try do
      switch
      |> Switch.changeset_update(params)
      |> Repo.update()
      |> LT.info("Persisted ppl_result for switch: ")
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  @doc """
  Returns batch_no in order batch with not done switches that are older than timestamp.
  """
  def get_older_not_done(timestamp, batch_no) do
    Switch
    |> where(ppl_done: false)
    |> where([s], s.inserted_at < ^timestamp)
    |> limit(100)
    |> offset(^calc_offset(batch_no))
    |> Repo.all()
    |> ToTuple.ok()
  rescue
    e -> {:error, e}
  end

  defp calc_offset(batch_no), do: batch_no * 100

  def get_by_id(id) do
    Switch |> Repo.get(id) |> return_tuple("Switch with id #{id} not found.")
  rescue
    e -> {:error, e}
  end

  def get_by_ppl_id(ppl_id) do
    Switch
    |> where(ppl_id: ^ppl_id)
    |> Repo.one()
    |> return_tuple("Switch with ppl_id #{ppl_id} not found")
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)
end
