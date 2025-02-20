defmodule Gofer.SwitchTrigger.Model.SwitchTriggerQueries do
  @moduledoc """
  Queries on SwitchTrigger type
  """
  import Ecto.Query

  alias Gofer.SwitchTrigger.Model.SwitchTrigger
  alias Gofer.EctoRepo, as: Repo
  alias LogTee, as: LT
  alias Util.ToTuple

  def insert(params) do
    id = Map.get(params, "id")
    request_token = Map.get(params, "request_token")

    try do
      %SwitchTrigger{}
      |> SwitchTrigger.changeset(params)
      |> Repo.insert()
      |> process_response(id, request_token)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp process_response(
         {:error, %Ecto.Changeset{errors: [switch_triggers_pkey: _message]}},
         id,
         _
       ) do
    {:error, {:switch_trigger_id_exists, id}}
  end

  defp process_response(
         {:error, %Ecto.Changeset{errors: [unique_request_token_for_switch_trigger: _message]}},
         _,
         request_token
       ) do
    request_token
    |> LT.info(
      "SwitchTriggerQueries.insert() - There is already switch_trigger with given request_token: "
    )

    {:error, {:request_token_exists, request_token}}
  end

  defp process_response({:ok, switch_trigger}, _id, request_token) do
    switch_trigger
    |> LT.info("Persisted switch_trigger with request_token: #{request_token}")
    |> ok_tuple()
  end

  def mark_as_processed(switch_trigger) do
    try do
      switch_trigger
      |> SwitchTrigger.changeset(%{"processed" => true})
      |> Repo.update()
      |> LT.info("Switch_trigger #{switch_trigger.id} marked as processed.")
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  @doc """
  Returns batch_no in order batch with unprocessed switch_triggers that are older than timestamp.
  """
  def get_older_unprocessed(timestamp, batch_no) do
    SwitchTrigger
    |> where(processed: false)
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
    SwitchTrigger |> Repo.get(id) |> return_tuple("SwitchTrigger with id #{id} not found.")
  rescue
    e -> {:error, e}
  end

  def get_by_request_token(request_token) do
    SwitchTrigger
    |> where(request_token: ^request_token)
    |> Repo.one()
    |> return_tuple("Switch_trigger with request_token #{request_token} not found")
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: error_tuple(nil_msg)
  defp return_tuple(value, _), do: ok_tuple(value)

  defp ok_tuple(data), do: {:ok, data}

  defp error_tuple(value), do: {:error, value}
end
