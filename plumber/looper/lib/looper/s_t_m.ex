defmodule Looper.STM do
  @moduledoc """
  State Transition Manager
  """

  alias Looper.Util
  alias Elixir.Util.Metrics
  alias LogTee, as: LT
  alias Looper.STM.{Impl, Publisher}
  alias Looper.STM.HandlerDispatcher, as: HDispatcher

  defmodule Behaviour do
    @moduledoc false

    @callback initial_query() :: Ecto.Query.t()
    @callback enter_scheduling(map) :: any()
    @callback terminate_request_handler(map, String.t()) :: any()
    @callback scheduling_handler(map) :: any()

    # Epilogue handler is executed _after_ exit scheduling transaction is done.
    # It is called even if transaction was aborted.
    #
    # Note: If some function in Ecto.Multi returns something other than {:ok, _}
    # or {:error, _} Multi will raise exception and epilogue handler will NOT be
    # executed in that case.)
    @callback epilogue_handler(map) :: any()
  end

  defmacro __using__(opts) do
    id                  = Util.get_mandatory_field(opts, :id)
    period_ms           = Util.get_mandatory_field(opts, :period_ms)
    repo                = Util.get_mandatory_field(opts, :repo)
    schema              = Util.get_mandatory_field(opts, :schema)
    observed_state      = Util.get_mandatory_field(opts, :observed_state)
    allowed_states      = Util.get_mandatory_field(opts, :allowed_states)
    cooling_time_sec    = Util.get_mandatory_field(opts, :cooling_time_sec)
    columns_to_log      = Util.get_mandatory_field(opts, :columns_to_log)
    publisher_cb        = Util.get_optional_field(opts, :publisher_cb, :skip)
    task_supervisor     = Util.get_optional_field(opts, :task_supervisor, :skip)

    quote do
      @behaviour Looper.STM.Behaviour

      use Looper.Periodic,
        period_ms: unquote(period_ms),
        metric_name: {"Ppl.beholder-wake_up", [Metrics.dot2dash(unquote(id))]},
        args: args()

      @publish_timeout 500
      @publish_retry_count 3

      @doc """
      Invoke callback with modified enter-scheduling quiery

      Can be used to speed-up scheduling of particular item.
      'predicate' modifies the query in such way that it picks particular item.

      If :raw option is given it will invoke defult enter_scheduling function (oldest event in state)
      and not the overriden one from particular looper instance.
      """
      def execute_now_with_predicate(predicate),
        do: GenServer.cast(__MODULE__, {:wake_up, predicate})

      def execute_now_with_predicate(predicate, :raw),
        do: GenServer.cast(__MODULE__, {:raw_execute_now, predicate})

      def execute_now_in_task(predicate) do
        options =
          args()
          |> Map.put(:initial_query, predicate.(args().initial_query))
          |> Map.put(:cooling_time_sec, 0)

        args().task_supervisor
        |> Task.Supervisor.start_child(__MODULE__, :recurring, [options])
      end

      def handle_cast({:wake_up, predicate}, state) do
        args()
        |> Map.put(:initial_query, predicate.(args().initial_query))
        |> Map.put(:cooling_time_sec, 0)
        |> recurring()

        {:noreply, state}
      end

      def handle_cast({:raw_execute_now, predicate}, state) do
        params =
          args()
          |> Map.put(:initial_query, predicate.(args().initial_query))
          |> Map.put(:cooling_time_sec, 0)

        with {:ok, %{enter_transition: item, select_item: selected}}
                <- Impl.enter_scheduling(params),
        do: keep_scheduling(item, selected, args()) |> log()

        {:noreply, state}
      end

      def recurring(params), do: params |> recurring_() |> log()

      def enter_scheduling(params) do
        with  {:ok, %{enter_transition: item, select_item: selected}}
                <- Impl.enter_scheduling(params),
          do: {:ok, {selected, item}}
      end

      def epilogue_handler(exit_state), do: exit_state

      defoverridable [enter_scheduling: 1, epilogue_handler: 1]

      defp recurring_(params) do
        with  {:ok, {selected, item}} <- enter_scheduling(params),
        do: keep_scheduling(item, selected, params)
      end

      defp keep_scheduling(_item = nil, _, params), do: {:ok, :no_item}
      defp keep_scheduling(item, selected, params) do
        Impl.report_metric(selected, unquote(id))
        with  {:ok, user_exit_function} when is_function(user_exit_function, 2)
                <- HDispatcher.call(selected.terminate_request, item,
                      &terminate_request_handler/2, &scheduling_handler/1),
        do:
          item
          |> Impl.exit_scheduling(user_exit_function, params)
          |> call_epilogue_handler
      end

      defp call_epilogue_handler(exit_state) do
        publish_event(exit_state, args().publisher_cb)
        epilogue_handler(exit_state)
        exit_state
      end

      defp publish_event(_exit_state, :skip), do: {:ok, :skip}
      defp publish_event({:ok, %{item: item = %{state: enter_state},
                           user_exit_function: %{state: exit_state}}}, publisher_cb)
        when enter_state != exit_state do

          Wormhole.capture(Publisher, :publish, [take_ids(item), exit_state, publisher_cb],
                           stacktrace: true, retry_count: @publish_retry_count,
                           timeout_ms: @publish_timeout)
      end
      defp publish_event(_exit_state, _publisher_cb), do: {:ok, :skip}

      defp take_ids(item) do
        item
        |> Map.from_struct()
        |> Enum.filter(fn {field_name, value} ->
          field_name |> Atom.to_string() |> String.ends_with?("_id")
        end)
        |> Enum.into(%{})
      end

      defp log({:ok, state}), do: {:ok, state}
      defp log(error), do: error |> LT.error("STM #{unquote(id)} FAILED")

      defp args() do %{
        repo:                unquote(repo),
        schema:              unquote(schema),
        initial_query:       initial_query(),
        observed_state:      unquote(observed_state),
        allowed_states:      unquote(allowed_states),
        cooling_time_sec:    unquote(cooling_time_sec),
        returning:           [:id, :terminate_request, :updated_at] ++
                               unquote(columns_to_log),
        publisher_cb:        unquote(publisher_cb),
        task_supervisor:     unquote(task_supervisor),
      }
      end
    end
  end
end
