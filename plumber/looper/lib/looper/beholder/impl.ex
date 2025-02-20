defmodule Looper.Beholder.Impl do
  @moduledoc """
  Functions periodically called by Beholder - Beholder body
  """

  require Looper.Ctx

  alias Looper.Ctx
  alias Looper.Beholder.Query
  alias Looper.Util
  alias Elixir.Util.Metrics

  def metric_name(id, tag), do: {"Beholder", [Metrics.dot2dash(id), tag]}

  def body(cfg) do
    abort_repeatedly_stuck(cfg)
    recover_stuck(cfg)
  end

  defp abort_repeatedly_stuck(cfg) do
    cfg
    |> Query.get_repeatedly_stuck()
    |> abort_repeatedly_stuck_(cfg)
  end

  defp abort_repeatedly_stuck_(results, cfg) do
    callback =  Map.get(cfg, :callback)
    results
    |> Query.abort_repeatedly_stuck(cfg)
    |> response_handler("stuck item aborted")
    |> send_state_watch_metric(cfg)
    |> call_callback?(results, callback)
  end

  defp call_callback?(results, _original, cb) when not is_function(cb), do: results
  defp call_callback?({:error, e}, _, _), do: {:error, e}
  defp call_callback?({:ok, results}, original, callback) do
    _ = original |> Enum.map(fn event -> callback.(event) end)
    results
  end

  defp send_state_watch_metric({:ok, results}, cfg) do
    Enum.each(results, fn event ->
      send_metrics(event, cfg)
    end)
    {:ok, results}
  end
  defp send_state_watch_metric(results, _cfg), do: results

  defp send_metrics(event, cfg) when is_map(event) do
    state = Map.get(event, :state, "")
    result = Map.get(event, :result, "")
    reason = Map.get(event, :result_reason, "")

    internal_metric_name =
      {"StateWatch.events_per_state",
       [Util.get_alias(cfg.query), state, concat(result, reason)]}

    external_metric = Map.get(cfg, :external_metric)
    if external_metric != :skip do
      external_metric_name = {external_metric, [state: state, result: concat(result, reason)]}

      Watchman.increment(
        internal: internal_metric_name,
        external: external_metric_name
      )
    else
      Watchman.increment(internal_metric_name)
    end
  end
  defp send_metrics(event, _cfg), do: event

  defp concat(result, reason) do
    to_str(result) <> "-" <> to_str(reason)
  end

  defp to_str(nil), do: ""
  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)

  defp recover_stuck(cfg) do
    cfg
    |> Query.recover_stuck()
    |> send_recovered_stuck_count(cfg)
    |> response_handler("stuck item recovered")
  end

  defp send_recovered_stuck_count(ctx = {n, _}, %{id: id}) do
    Watchman.submit(metric_name(id, "stuck_item_recovered"), n, :count)

    ctx
  end
  defp send_recovered_stuck_count(ctx, _), do: ctx

  defp response_handler({_n, recovered}, msg) do
    recovered |> Enum.each(&log(&1, msg))
    recovered |> Util.return_ok_tuple()
  end

  defp response_handler(ctx, msg) do
     Ctx.error("Beholder error while: #{msg}")
     {:error, ctx}
  end

  defp log(ctx, msg), do: Ctx.warn(msg)
end
