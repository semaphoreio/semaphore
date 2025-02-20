defmodule Looper.STM.Impl do
  @moduledoc """
  State transition manager implementation
  """

  alias Ecto.Multi
  alias Looper.STM.Query
  alias LogTee, as: LT
  alias Util.Metrics

  require Looper.Ctx
  alias Looper.Ctx


  @doc """
  Select item to transition from observed_state to observed_state_in_scheduling
  """
  def enter_scheduling(args) do
    Multi.new
    |> Multi.run(:select_item, fn _repo, _ -> Query.select_item_to_schedule(args) end)
    |> Multi.run(:enter_transition, fn
      _repo, %{select_item: nil}  -> {:ok, nil}
      _repo, %{select_item: item} -> Query.transition_to_scheduling(item.id, args)
    end)
    |> args.repo.transaction()
    |> LT.debug("ENTER_SCHEDULING")
  end

  @doc """
  Transition item out of in_scheduling state.

  Package received user_exit_function into Ecto.Multi object and
  as last step in 'multi' move the item out of "scheduling" and
  into the state specified in response of user_exit_function.
  .
  """
  def exit_scheduling(item, user_exit_function, args) do
    Multi.new()
    |> Multi.run(:item, fn _repo, _ -> {:ok, item} end)
    |> Multi.run(:user_exit_function, user_exit_function)
    |> Multi.run(:exit_transition, __MODULE__, :exit_transition, [args])
    |> args.repo.transaction()
    |> LT.debug("EXIT_SCHEDULING")
    |> log_state_change()
  end

  def exit_transition(_repo, results, args) do
    results
    |> get_in([:user_exit_function, :state])
    |> valid_state(Map.get(args, :allowed_states))
    |> exit_transition_(results, args)
  end

  defp valid_state(next_state, allowed_states), do:
    valid_state(next_state in allowed_states, next_state, allowed_states)

  defp valid_state(true,  next_state, _allowed_states), do: {:ok, next_state}
  defp valid_state(false, next_state, allowed_states),  do:
    {:error, {:unknown_state, next_state, :allowed_states, allowed_states}}

  defp exit_transition_({:ok, _next_state}, results, args) do
    results
    |> Map.get(:item)
    |> Query.to_state(values2update(results), args)
  end
  defp exit_transition_(error, _, _), do: error

  defp values2update(results), do:
    results |> Map.get(:user_exit_function) |> Map.to_list()

  def report_metric(item, id) do
    time_since_last_scheduling = item.updated_at |> time_in_ms_since()

    {"Ppl.time_since_last_scheduling", [Metrics.dot2dash(id)]}
    |> Watchman.submit(time_since_last_scheduling, :timing)
  end

  defp time_in_ms_since(last_scheduling) do
    DateTime.utc_now
    |> DateTime.to_naive
    |> NaiveDateTime.diff(last_scheduling, :millisecond)
  end

  defp log_state_change(response = {:ok, data}) do
    old_state = data |> Map.get(:item) |> Map.get(:state)
    new_state = data |> Map.get(:exit_transition) |> Map.get(:state)

    if old_state != new_state do
      response |> Ctx.event("exit_scheduling")
    else
      response
    end
  end

  defp log_state_change(response), do: response |> Ctx.event("exit_scheduling")

end
