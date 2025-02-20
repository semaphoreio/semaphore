defmodule Gofer.Actions.DescribeManyImpl do
  @moduledoc """
  Module which implements DescribeMany switches action
  """
  alias Gofer.Actions
  alias Util.ToTuple
  alias LogTee, as: LT

  @count_limit 10

  def describe_many(switch_ids, events_per_target, requester_id) do
    switch_ids
    |> check_number_limits()
    |> Enum.find(:all_ids_uuid, fn x -> not_uuid(x) end)
    |> describe_many_(switch_ids, events_per_target, requester_id)
    |> ToTuple.ok()
  catch
    error ->
      error |> LT.error("Describe_many request failure") |> ToTuple.error()
  end

  defp not_uuid(id) do
    case UUID.info(id) do
      {:ok, _} -> false
      _ -> true
    end
  end

  defp check_number_limits(list)
       when length(list) <= @count_limit,
       do: list

  defp check_number_limits(list),
    do: throw("Requested #{length(list)} switches which is more than limit of #{@count_limit}.")

  defp describe_many_(:all_ids_uuid, switch_ids, events_per_target, requester_id) do
    Enum.map(switch_ids, fn switch_id ->
      case Actions.describe_switch(switch_id, events_per_target, requester_id) do
        {:ok, {:NOT_FOUND, msg}} -> throw({:NOT_FOUND, msg})
        {:ok, switch_details} -> switch_details
        {:error, message} -> throw(message)
      end
    end)
  end

  defp describe_many_(invalid_id, _switch_ids, _events_per_target, _requester_id),
    do: throw({:NOT_FOUND, "Switch with id: '#{invalid_id}' not found."})
end
