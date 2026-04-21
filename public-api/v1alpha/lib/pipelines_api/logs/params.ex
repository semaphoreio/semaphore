defmodule PipelinesAPI.Logs.Params do
  @moduledoc false

  @truthy_full_values ~w(1 true yes)

  def full_logs_requested_for_job?(params, _job), do: full_logs_requested?(params)

  def full_logs_requested?(params) when is_map(params) do
    params
    |> Map.get("full", "")
    |> full_logs_value?()
  end

  def full_logs_requested?(_params), do: false

  defp full_logs_value?(value) when is_binary(value),
    do: value |> String.downcase() |> Kernel.in(@truthy_full_values)

  defp full_logs_value?(_value), do: false
end
