defmodule PipelinesAPI.Util.VerifyData do
  @moduledoc """
  VerifyData module is used to perform data validation.
  """

  use Plug.Builder
  alias PipelinesAPI.Util.ToTuple

  @uuid_regex ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

  def is_valid_uuid?(nil), do: true

  def is_valid_uuid?(value) when is_binary(value), do: String.match?(value, @uuid_regex)

  def is_valid_uuid?(_), do: false

  def is_present_string?(nil), do: false

  def is_present_string?(val) when is_binary(val), do: String.length(val) > 0

  def is_present_string?(_val), do: false

  def is_string_length?(val, min_length, max_length, required? \\ false),
    do: is_string_length_?(val, min_length, max_length, required?)

  defp is_string_length_?(nil, _min_length, _max_length, required?), do: not required?

  defp is_string_length_?(str, min_length, max_length, _required?) when is_binary(str) do
    String.length(str) >= min_length and String.length(str) <= max_length
  end

  defp is_string_length_?(_str, _min_length, _max_length, _required?), do: false

  def non_empty_list?(val) when is_list(val) and length(val) > 0, do: true

  def non_empty_list?(_val), do: false

  def verify(:ok), do: :ok

  def verify(error = {:error, _}), do: error

  def verify(true), do: :ok

  def verify(false), do: ToTuple.user_error("bad data")

  def verify(_), do: ToTuple.internal_error("internal error")

  def verify(:ok, val), do: verify(val)

  def verify(error = {:error, _}, _val), do: error

  def verify(true, _message), do: :ok

  def verify(false, message), do: ToTuple.user_error(message)

  def verify(_, _), do: ToTuple.internal_error("internal error")

  def verify(:ok, val, msg), do: verify(val, msg)

  def verify(error = {:error, _}, _val, _msg), do: error

  def verify(_, _, _), do: ToTuple.internal_error("internal error")

  def finalize_verification(result, conn = %{params: params}, enabled_fields) do
    case result do
      :ok ->
        Map.put(conn, :params, Map.take(params, enabled_fields))

      {:error, {:user, message}} ->
        conn |> resp(400, message) |> halt

      {:error, {:internal, message}} ->
        conn |> resp(500, message) |> halt

      {:error, _} ->
        conn |> resp(500, "internal error") |> halt
    end
  end
end
