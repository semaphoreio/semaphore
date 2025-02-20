defmodule Looper.StateResidency.Query do
  @moduledoc """
  StateResidency queries
  """

  alias Looper.Util

  def get_durations_for_state(params, state) do
    params
    |> sql_query(state)
    |> execute(:query, params.repo)
    |> proces_response(state)
  rescue
    e -> {:error, e}
  catch
    a, b -> {:error, [a, b]}
  end

  defp sql_query(params, state) do
    """
    SELECT
      e.state,
      max(#{duration_till_now_in_ms(params, state)}) AS "max_duration_ms",
      percentile_disc(0.9) WITHIN GROUP
        (ORDER BY #{duration_till_now_in_ms(params, state)}) AS "p90_duration_ms"
    FROM #{params.schema} as e
    LEFT JOIN #{params.trace_schema} as et
      ON e.#{params.schema_id}=et.#{params.trace_schema_id}
    WHERE e.state='#{state}'
    GROUP BY e.state
    """
  end

  defp duration_till_now_in_ms(params, state) do
    """
    ROUND ((EXTRACT (EPOCH FROM now()) -
            EXTRACT (EPOCH FROM et.#{get_timestamp_name_for_state(params, state)})) * 1000)
    """
  end

  defp get_timestamp_name_for_state(params, state),
    do: params.states_to_timestamps_map |> Map.get(state) |> to_str()

  defp to_str(val) when is_atom(val), do: Atom.to_string(val)
  defp to_str(val) when is_binary(val), do: val

  defp execute(q, operation, repo), do:
    apply(repo, operation, [q])

  # Example of :ok result:
  #
  # {:ok, %Postgrex.Result{columns: ["state", "max_duration_ms", "p90_duration_ms"],
  # command: :select, connection_id: 947, num_rows: 1,
  # rows: [["stateA", 10074.0, 3016.0]]}}
  defp proces_response({:ok, response = %Postgrex.Result{}}, state) do
    response.columns
    |> length()
    |> Range.new(1)
    |> Enum.reduce(%{}, fn ind, acc ->
      key = response.columns |> Enum.at(ind - 1) |> String.to_atom()
      value = process_value(response.rows, ind, key, state)
      Map.put(acc, key, value)
    end)
    |> Util.return_ok_tuple()
  end
  defp proces_response(error, _state), do: Util.return_error_tuple(error)

  defp process_value(rows, ind, _column, _state) when length(rows) > 0,
    do: rows |> Enum.at(0) |> Enum.at(ind - 1)
  defp process_value(_rows, _ind, :state, state), do: state
  defp process_value(_rows, _ind, _column, _state), do: 0.0
end
