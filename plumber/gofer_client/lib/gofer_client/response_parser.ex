defmodule GoferClient.ResponseParser do
  @moduledoc """
  Module serves to parse Gofer service proto message response and to return
  {:ok, switch_id} or {error, ...}
  """

  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias LogTee, as: LT
  alias Util.ToTuple

  # Create

  def process_create_response({:ok, :switch_not_defined}), do: {:ok, ""}

  def process_create_response({:ok, create_response}) do
    with true                   <- is_map(create_response),
         {:ok, response_status} <- Map.fetch(create_response, :response_status),
         :OK                    <- response_code_value(response_status),
         {:ok, switch_id}       <- Map.fetch(create_response, :switch_id)
    do {:ok, switch_id}
    else
      :BAD_PARAM -> create_response.response_status |> Map.get(:message) |> ToTuple.error()
      :MALFORMED -> create_response.response_status |> Map.get(:message) |> ToTuple.error(:malformed)
        _ -> log_invalid_response(create_response, "create")
    end
  end

  def process_create_response(error), do: error

  # PipelineDone

  def process_pipeline_done_response({:ok, :switch_not_defined}), do: {:ok, ""}

  def process_pipeline_done_response({:ok, response}) do
    with true                   <- is_map(response),
         {:ok, response_status} <- Map.fetch(response, :response_status),
         :OK                    <- response_code_value(response_status)
    do {:ok, response_status.message}
    else
        :BAD_PARAM -> response.response_status |> Map.get(:message) |> ToTuple.error()
        :RESULT_CHANGED -> response.response_status |> Map.get(:message) |> ToTuple.error()
        :RESULT_REASON_CHANGED -> response.response_status |> Map.get(:message) |> ToTuple.error()
        :NOT_FOUND -> response.response_status |> Map.get(:message) |> ToTuple.error()
        _ -> log_invalid_response(response, "pipeline_done")
    end
  end

  def process_pipeline_done_response(error), do: error

  # Util

  defp response_code_value(%{code: code}) do
    ResponseCode.key(code)
  rescue _ ->
    nil
  end
  defp response_code_value(_), do: nil

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Gofer service responded to #{rpc_method} with :ok and invalid data:")
    |> ToTuple.error()
  end
end
