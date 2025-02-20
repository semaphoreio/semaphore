defmodule Gofer.PlumberClient.ResponseParser do
  @moduledoc """
  Module serves to parse Plumber service proto message response and to return
  {:ok, response} or {error, ...}
  """

  alias InternalApi.Plumber.{ScheduleExtensionResponse, DescribeResponse}
  alias Util.ToTuple
  alias LogTee, as: LT

  # ScheduleExtension

  def parse_response(response = %ScheduleExtensionResponse{}) do
    with true <- is_map(response),
         {:ok, response_status} <- Map.fetch(response, :response_status),
         :OK <- response_status.code,
         {:ok, ppl_id} <- Map.fetch(response, :ppl_id) do
      {:ok, ppl_id}
    else
      :BAD_PARAM -> response.response_status |> Map.get(:message) |> ToTuple.error(:bad_param)
      _ -> log_invalid_response(response, "schedule_extension")
    end
  end

  # Describe

  def parse_response(response = %DescribeResponse{}) do
    with true <- is_map(response),
         {:ok, response_status} <- Map.fetch(response, :response_status),
         :OK <- response_status.code,
         {:ok, pipeline} <- Map.fetch(response, :pipeline),
         {:ok, ppl_state} <- pipeline |> Map.get(:state) |> state_code_value(),
         {:ok, ppl_result} <- pipeline |> Map.get(:result) |> result_code_value(),
         {:ok, ppl_result_reason} <- get_result_reason(pipeline, ppl_result),
         ppl_done_at <- pipeline |> Map.get(:done_at) |> get_seconds() do
      {:ok, ppl_state, ppl_result, ppl_result_reason, ppl_done_at}
    else
      :BAD_PARAM -> response.response_status |> Map.get(:message) |> ToTuple.error(:bad_param)
      :LIMIT_EXCEEDED -> {:error, :limit_exceeded}
      _ -> log_invalid_response(response, "describe")
    end
  end

  defp get_result_reason(pipeline, result) do
    pipeline |> Map.get(:result_reason) |> result_reason_code_value(result)
  end

  defp state_code_value(code) do
    code |> Atom.to_string() |> String.downcase() |> ToTuple.ok()
  rescue
    _ ->
      {:error, "Invalid pipeline state code: #{code}"}
  end

  defp result_code_value(code) do
    code |> Atom.to_string() |> String.downcase() |> ToTuple.ok()
  rescue
    _ ->
      {:error, "Invalid pipeline result code: #{code}"}
  end

  defp result_reason_code_value(:TEST, result) when result != "failed", do: {:ok, ""}

  defp result_reason_code_value(code, _result) do
    code |> to_string() |> String.downcase() |> ToTuple.ok()
  rescue
    _ ->
      {:error, "Invalid pipeline result code: #{code}"}
  end

  defp get_seconds(nil), do: 0
  defp get_seconds(%{seconds: value}), do: value

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Plumber service responded to #{rpc_method} with :ok and invalid data:")
    |> ToTuple.error()
  end
end
