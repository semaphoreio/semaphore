defmodule Ppl.AfterPplTasks.Model.AfterPplTasksQueries do
  @moduledoc """
  Queries and operations on AfterPplTasks type
  """

  import Ecto.Query

  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Util.ToTuple
  alias Ppl.AfterPplTasks.Model.AfterPplTasks

  @doc """
  Inserts new AfterPplTasks record into DB with given parameters
  """
  def insert(ppl_req) do
    params =
      %{ppl_id: ppl_req.id}
      |> Map.put(:state, "waiting")
      |> Map.put(:in_scheduling, "false")

    try do
      %AfterPplTasks{}
      |> AfterPplTasks.changeset(params)
      |> Repo.insert()
      |> process_response(ppl_req.id)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  @doc """
  Finds AfterPplTask by ppl_id
  """
  def get_by_id(id) do
    AfterPplTasks
    |> where(ppl_id: ^id)
    |> Repo.one()
    |> return_tuple("AfterPplTasks with id: '#{id}' not found.")
  rescue
    e -> {:error, e}
  end

  @doc """
  Determines if after ppl task should be created based on request
  """
  def present?(_ppl_request = %{definition: %{"after_pipeline" => _}}), do: true
  def present?(_), do: false

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _), do: ToTuple.ok(value)

  defp process_response({:error, %Ecto.Changeset{errors: [one_limit_per_ppl: _message]}}, ppl_id) do
    ppl_id
    |> LT.info(
      "AfterPplTasksQueries.insert() - There is already after_ppl_task for pipeline with ppl_id: "
    )

    get_by_id(ppl_id)
  end

  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _) do
    {:error, Map.put(%{}, key, message)}
  end

  defp process_response({:ok, after_ppl_task}, ppl_id) do
    after_ppl_task
    |> LT.info("Persisted after_ppl_task for pipeline with ppl_id: #{ppl_id}")
    |> ToTuple.ok()
  end
end
