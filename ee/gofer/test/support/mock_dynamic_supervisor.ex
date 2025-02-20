defmodule Test.MockDynamicSupervisor do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: args[:name])
  end

  def child_spec(args) do
    %{id: args[:name], start: {__MODULE__, :start_link, [args]}}
  end

  def set_response(name, response) do
    GenServer.call(name, {:set_response, response})
  end

  def clear_response(name) do
    set_response(name, nil)
  end

  def get_calls(name) do
    GenServer.call(name, :get_calls)
  end

  def clear_calls(name) do
    GenServer.call(name, :clear_calls)
  end

  def init(args) do
    mock_response = Keyword.get(args, :mock_response, nil)
    call_extractor = Keyword.get(args, :call_extractor, & &1)
    {:ok, %{response: mock_response, call_extractor: call_extractor, calls: []}}
  end

  def handle_call({:start_child, child}, _from, state = %{calls: calls}) do
    call_arg = child |> elem(0) |> elem(2) |> List.first() |> state.call_extractor.()
    call = Enum.find(calls, {call_arg, random_pid()}, fn {arg, _pid} -> arg == call_arg end)

    {calls, response} =
      if not Enum.member?(calls, call),
        do: {calls ++ [call], {:ok, elem(call, 1)}},
        else: {calls, {:error, {:already_started, elem(call, 1)}}}

    response = if state.response, do: state.response, else: response
    {:reply, response, %{state | calls: calls}}
  end

  def handle_call({:set_response, response}, _from, state) do
    {:reply, :ok, %{state | response: response}}
  end

  def handle_call(:get_calls, _from, state = %{calls: calls}) do
    {:reply, {:ok, calls}, state}
  end

  def handle_call(:clear_calls, _from, state = %{calls: calls}) do
    {:reply, {:ok, calls}, %{state | calls: []}}
  end

  def handle_call(:count_children, _from, state = %{calls: calls}) do
    {:reply, [active: length(calls)], state}
  end

  defp random_pid(), do: :c.pid(0, :rand.uniform(4_096), :rand.uniform(64))
end
