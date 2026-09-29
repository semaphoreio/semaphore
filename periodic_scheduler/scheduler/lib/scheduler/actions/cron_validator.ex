defmodule Scheduler.Actions.CronValidator do
  @moduledoc """
  Parses cron expressions. Wraps `Crontab.CronExpression.Parser.parse/1` via
  Wormhole so raises are turned into `{:error, reason}` tuples rather than
  process exits.
  """

  alias Crontab.CronExpression.Parser

  @spec parse(String.t()) :: {:ok, Crontab.CronExpression.t()} | {:error, term()}
  def parse(expression) do
    Wormhole.capture(Parser, :parse, [expression], skip_log: true, ok_tuple: true)
  end
end
