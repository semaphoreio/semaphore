defmodule Ppl.TimeLimits.Model.TimeLimitsQueries do
  @moduledoc """
  Time Limits Queries
  Operations on Time Limit  type
  """

  import Ecto.Query

  alias Ppl.EctoRepo, as: Repo
  alias Ppl.TimeLimits.Model.TimeLimits

  @doc """
  Inserts or updates time limit for a specific pipeline or block
  """
  def set_time_limit(entity, type) do
    params =
     %{ppl_id: entity.ppl_id, type: type, state: "tracking", in_scheduling: false}
      |> set_deadline(entity)
      |> add_block_index?(entity, type)

    %TimeLimits{}
    |> TimeLimits.changeset(params)
    |> Repo.insert()
    |> process_response(entity, type)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp set_deadline(params, entity) do
    params |> Map.put(:deadline, calculate_deadline(entity))
  end

  defp calculate_deadline(entity) do
    DateTime.utc_now() |> Timex.shift(minutes: entity.exec_time_limit_min)
  end

  defp add_block_index?(params, entity, "ppl_block"),
    do: params |> Map.put(:block_index, entity.block_index)
  defp add_block_index?(params, _entity, _type), do: params

  defp process_response({:error, %Ecto.Changeset{errors: [one_limit_per_ppl_or_block: _message]}}, entity, type) do
    update_deadline(entity, type)
  end
  defp process_response(response, _entity, _type), do: response

  defp update_deadline(entity, type) do
    TimeLimits
    |> where(ppl_id: ^entity.ppl_id)
    |> where(type: ^type)
    |> query_by_block_index?(entity, type)
    |> update(set: [deadline: ^calculate_deadline(entity)])
    |> select([e], e)
    |> Repo.update_all([])
    |> update_success?()
  end

  defp query_by_block_index?(query, entity, "ppl_block"),
    do: query |> where(block_index: ^entity.block_index)
  defp query_by_block_index?(query, _entity, _type), do: query

  # It has to be exactly 1 item
  defp update_success?({1, [item]}), do: {:ok, item}
  defp update_success?(resp), do: {:error, resp}

  @doc """
  Sets terminate request fields for given time limit
  """
  def terminate(tl, t_request, t_request_desc) do
    params = %{terminate_request: t_request, terminate_request_desc: t_request_desc}
    tl
    |> TimeLimits.changeset(params)
    |> Repo.update()
  end

  @doc """
  Get the time limit for a specific pipeline
  """
  def get_by_id(id) do
      TimeLimits
      |> where(ppl_id: ^id)
      |> where(type: "pipeline")
      |> Repo.one()
      |> return_tuple("Time limit for pipeline with id: #{id} not found")
    rescue
      e -> {:error, e}
  end

  @doc """
  Get the time limit for a specific block
  """
  def get_by_id_and_index(id, index) do
      TimeLimits
      |> where(ppl_id: ^id)
      |> where(block_index: ^index)
      |> where(type: "ppl_block")
      |> Repo.one()
      |> return_tuple("Time limit for block #{index} of pipeline with id: #{id} not found")
    rescue
      e -> {:error, e}
  end

  defp return_tuple(nil, nil_msg), do: return_error_tuple(nil_msg)
  defp return_tuple(value, _),     do: return_ok_tuple(value)

  defp return_ok_tuple(value), do: {:ok, value}

  defp return_error_tuple(value), do: {:error, value}
end
