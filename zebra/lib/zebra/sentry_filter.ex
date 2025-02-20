defmodule Zebra.SentryFilter do
  @behaviour Sentry.EventFilter
  require Logger

  def exclude_exception?(e = %DBConnection.ConnectionError{}, _) do
    #
    # There were about 1000/day events on Sentry that are related to DB
    # connections comming from Zebra. All of them were harmless.
    #
    # Filling Sentry with junk data is contraproductive. Instead of sending to
    # Sentry, we are logging it. In case of problems, logs will indicate the
    # problem.
    #

    Logger.error("DB Connection Error: #{inspect(e)}")
    true
  end

  def exclude_exception?(_exception, _source), do: false
end
