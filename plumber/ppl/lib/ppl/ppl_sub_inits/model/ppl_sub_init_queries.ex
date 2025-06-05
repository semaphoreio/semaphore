defmodule Ppl.PplSubInits.Model.PplSubInitsQueries do
  @moduledoc """
  Queries and operations on PplSubInit  type
  """

  import Ecto.Query

  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo
  alias Util.ToTuple
  alias Ppl.PplSubInits.Model.PplSubInits

  @doc """
  Inserts new PplSubInit record into DB with given parameters
  """
  def insert(ppl_req, init_type, start_in_conceived? \\ false) do
    params =
      %{ppl_id: ppl_req.id, init_type: init_type}
      |> Map.put(:state, if(start_in_conceived?, do: "conceived", else: "created"))
      |> Map.put(:in_scheduling, "false")
    try do
      %PplSubInits{} |> PplSubInits.changeset(params) |> Repo.insert()
      |> process_response(ppl_req.id)
    rescue
      e -> {:error, e}
    catch
      a, b -> {:error, [a, b]}
    end
  end

  defp process_response({:error, %Ecto.Changeset{errors: [one_ppl_sub_init_per_ppl_request: _message]}}, ppl_id) do
    ppl_id
    |> LT.info("PplSubInitsQueries.insert() - There is already ppl_sub_init for pipeline with ppl_id: ")
    {:error, {:ppl_id_exists, ppl_id}}
  end
  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _) do
    {:error, Map.put(%{}, key, message)}
  end
  defp process_response({:ok, psi}, ppl_id) do
    psi
    |> LT.info("Persisted ppl_sub_init for pipeline with ppl_id: #{ppl_id}")
    |> ToTuple.ok()
  end

  @doc """
  Sets terminate request fields for given PplSubInit
  """
  def terminate(psi, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    psi
    |> PplSubInits.changeset(params)
    |> Repo.update()
  end

  @doc """
  Finds PplSubInit by ppl_id
  """
  def get_by_id(id) do
      PplSubInits |> where(ppl_id: ^id) |> Repo.one()
      |> return_tuple("PplSubInit with id: '#{id}' not found.")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _),     do: ToTuple.ok(value)
end
