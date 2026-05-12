defmodule Projecthub.PeriodicValidators do
  @moduledoc """
  Shared pre-flight validators for schedulers / periodic tasks before
  they are sent to the periodic_scheduler service. Mirrors the remote
  service's own validation so we can fail fast in projecthub, before
  any destructive (delete) call has been made.

  Each validator is a 1-arity function: `(item) -> :ok | {:error, String.t()}`.
  Caller modules maintain their own `@validators` list and pass it to
  `validate_all/2`. Lists may freely mix shared validators from this
  module with module-local validators.
  """

  alias Crontab.CronExpression.Parser

  @doc """
  Run validators over each item. Halts on the first error.
  """
  def validate_all(items, validators) do
    Enum.reduce_while(items, :ok, fn item, _acc ->
      case run_validators(item, validators) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  defp run_validators(item, validators) do
    Enum.reduce_while(validators, :ok, fn validator, _acc ->
      case validator.(item) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  # Skip when recurring is explicitly false — matches
  # Scheduler.Actions.PersistImpl.validate_cron_expression/1 in periodic_scheduler.
  def validate_cron(%{recurring: false}), do: :ok

  def validate_cron(%{at: at, name: name}) do
    case Parser.parse(at) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        {:error, "Invalid cron expression in task '#{name}': #{inspect(reason)}"}
    end
  end
end
