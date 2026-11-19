defmodule Ppl.Ppls.Beholder do
  @moduledoc """
  Periodically scans 'pipelines' table searching for
  pipelines stuck in scheduling.

  If pipeline is in scheduling state more than '@threshold_sec'
  Beholder will:
  - move it out of cheduling
  - increment ppl's recovery counter

  If recovery counter is higher than 'threshold_count'
  pipeline will transition to `done`.
  """

  require Logger

  alias Ppl.PplTraces.Model.PplTracesQueries
  alias Ppl.Ppls.STMHandler.Common
  alias Looper.STM.Publisher
  alias Ppl.PplBlocks.Model.PplBlocksQueries
  alias Ppl.PplSubInits.Model.PplSubInitsQueries

  @period_sec Application.compile_env!(:ppl, :beholder_sleep_period_sec)
  @threshold_sec Application.compile_env!(:ppl, :beholder_threshold_sec)
  @threshold_count Application.compile_env!(:ppl, :beholder_threshold_count)

  use Looper.Beholder,
    id: __MODULE__,
    period_sec: @period_sec,
    query: Ppl.Ppls.Model.Ppls,
    excluded_states: ["done"],
    terminal_state: "done",
    result_on_abort: "failed",
    result_reason_on_abort: "stuck",
    repo: Ppl.EctoRepo,
    threshold_sec: @threshold_sec,
    threshold_count: @threshold_count,
    external_metric: "Pipelines.state",
    callback: fn ppl -> apply(__MODULE__, :post_proccessing, [ppl]) end

  # terminate_sub_init/1 must precede terminate_ppl_blks/1: its write waits on the
  # sub-init row lock held while regular_init creates blocks, so they are visible.
  @post_processing_steps [
    :set_done_at_timestamp,
    :terminate_sub_init,
    :terminate_ppl_blks,
    :publish_done
  ]

  def post_proccessing(ppl) do
    Enum.each(@post_processing_steps, &run_step(&1, ppl))
  end

  defp run_step(step, ppl) do
    case apply(__MODULE__, step, [ppl]) do
      {:error, reason} -> log_failure(step, ppl, "error: #{error_name(reason)}")
      result -> result
    end
  catch
    kind, reason -> log_failure(step, ppl, "#{kind}: #{error_name(reason)}")
  end

  defp log_failure(step, ppl, details) do
    Logger.error("Ppl.Ppls.Beholder #{step} failed for ppl_id: #{ppl.ppl_id}, #{details}")
  end

  # Only a tag is logged: database error details carry row values and exit
  # payloads can carry the AMQP URL.
  defp error_name(%Postgrex.Error{postgres: %{code: code}}), do: "Postgrex.Error #{code}"

  defp error_name(%DBConnection.ConnectionError{message: message}),
    do: "DBConnection.ConnectionError #{String.slice(message, 0, 200)}"

  defp error_name(reason) when is_exception(reason), do: inspect(reason.__struct__)
  defp error_name(reason) when is_atom(reason), do: inspect(reason)
  defp error_name(reason) when is_binary(reason), do: String.slice(reason, 0, 200)
  defp error_name({tag, _payload}) when is_atom(tag), do: inspect(tag)
  defp error_name(_reason), do: "unrecognized reason"

  def publish_done(ppl) do
    Publisher.publish(
      Map.take(ppl, [:ppl_id]),
      "done",
      fn params -> Common.publisher_callback(params) end
    )
  end

  def set_done_at_timestamp(ppl) do
    PplTracesQueries.set_timestamp(ppl.ppl_id, :done_at)
  end

  def terminate_sub_init(ppl) do
    case PplSubInitsQueries.get_by_id(ppl.ppl_id) do
      {:ok, %{state: state, terminate_request: nil} = psi} when state != "done" ->
        PplSubInitsQueries.terminate(psi, "stop", "Pipeline terminated")

      {:ok, psi} ->
        {:ok, psi}

      error ->
        error
    end
  end

  def terminate_ppl_blks(ppl) do
    PplBlocksQueries.terminate_all(ppl.ppl_id, "cancel", "Pipeline terminated")
  end
end
