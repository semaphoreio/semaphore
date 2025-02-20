defmodule Ppl.PplOrigins.Model.PplOriginsQueries do
  @moduledoc """
  PplOrigins Queries
  Operations on PplOrigins type
  """

  import Ecto.Query

  alias Ppl.PplOrigins.Model.PplOrigins
  alias Util.ToTuple
  alias LogTee, as: LT
  alias Ppl.EctoRepo, as: Repo

  def insert(ppl_id, initial_request) do
    params = %{ppl_id: ppl_id, initial_request: initial_request}

    %PplOrigins{} |> PplOrigins.changeset(params) |> Repo.insert()
    |> process_response(params.ppl_id)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp process_response({:error, %Ecto.Changeset{errors: [one_origin_per_ppl: _message]}}, ppl_id) do
    LT.info(ppl_id, "PplOriginsQueries.insert() - There is already origin data for pipeline with id:")
    get_by_id(ppl_id)
  end
  defp process_response({:error, %Ecto.Changeset{errors: [{key, message}]}}, _ppl_id) do
    {:error, Map.put(%{}, key, message)}
  end
  defp process_response({:ok, ppl_def}, _ppl_id), do: {:ok, ppl_def}

  def save_definition(ppl_or, initial_definition) do
    params = %{initial_definition: initial_definition}

    ppl_or |> PplOrigins.changeset_definition(params) |> Repo.update()
  end

  def get_by_id(id) do
    PplOrigins |> where(ppl_id: ^id) |> Repo.one()
    |> return_tuple("Pipeline origin for pipeline with id: #{id} not found")
  rescue
    e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: ToTuple.error(nil_msg)
  defp return_tuple(value, _),     do: ToTuple.ok(value)
end
