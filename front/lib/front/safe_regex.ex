defmodule Front.SafeRegex do
  @moduledoc """
  Bounded regex matching for parameter input format validation. Caps
  pattern and value sizes; PCRE's `match_limit` short-circuits runaway
  matches. Keep in sync with `Scheduler.SafeRegex` (canonical copy).
  """

  @max_pattern_length 512
  @max_value_length 4_096

  @type match_error :: :pattern_too_long | :value_too_long | :invalid_pattern

  @spec max_pattern_length() :: pos_integer()
  def max_pattern_length, do: @max_pattern_length

  @spec max_value_length() :: pos_integer()
  def max_value_length, do: @max_value_length

  @spec match(String.t() | nil, String.t() | nil) ::
          {:ok, boolean()} | {:error, match_error()}
  def match(nil, _value), do: {:error, :invalid_pattern}
  def match(_pattern, nil), do: {:ok, false}

  def match(pattern, value) when is_binary(pattern) and is_binary(value) do
    cond do
      byte_size(pattern) > @max_pattern_length -> {:error, :pattern_too_long}
      byte_size(value) > @max_value_length -> {:error, :value_too_long}
      true -> run(pattern, value)
    end
  end

  defp run(pattern, value) do
    case :re.compile(pattern) do
      {:ok, compiled} ->
        case :re.run(value, compiled) do
          {:match, _captures} -> {:ok, true}
          :nomatch -> {:ok, false}
        end

      {:error, _reason} ->
        {:error, :invalid_pattern}
    end
  end
end
