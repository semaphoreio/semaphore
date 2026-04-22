defmodule PipelinesAPI.Logs.Params do
  @moduledoc false

  @truthy_artifact_job_logs_values ~w(1 true yes)

  def artifact_job_logs_requested_for_job?(params, _job), do: artifact_job_logs_requested?(params)

  def artifact_job_logs_requested?(params) when is_map(params) do
    params
    |> Map.get("artifact_job_logs", "")
    |> artifact_job_logs_value?()
  end

  def artifact_job_logs_requested?(_params), do: false

  defp artifact_job_logs_value?(value) when is_binary(value),
    do: value |> String.downcase() |> Kernel.in(@truthy_artifact_job_logs_values)

  defp artifact_job_logs_value?(_value), do: false
end
