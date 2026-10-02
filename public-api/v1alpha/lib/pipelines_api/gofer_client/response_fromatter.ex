defmodule PipelinesAPI.GoferClient.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from Gofer service and transforming it
  from protobuf messages into more suitable format for HTTP communication with
  API clients
  """

  alias LogTee, as: LT
  alias PipelinesAPI.Util.ToTuple
  alias Util.Proto

  # List

  def process_list_response({:ok, list_response}) do
    with {:ok, response} <- Proto.to_map(list_response),
         :OK <- response.response_status.code,
         promotions <- get_promotions(response),
         {:ok, response} <- form_list_page(promotions, response) do
      {:ok, response}
    else
      :NOT_FOUND -> list_response.response_status |> Map.get(:message) |> ToTuple.user_error()
      _ -> log_invalid_response(list_response, "list")
    end
  end

  def process_list_response(error), do: error

  defp get_promotions(list_response) do
    list_response.trigger_events
    |> Enum.map(&format_trigger_event(&1))
  end

  defp format_trigger_event(tge) do
    %{
      name: tge.target_name,
      triggered_at: tge.triggered_at,
      triggered_by: tge.triggered_by,
      override: tge.override,
      status: decide_status(tge),
      scheduled_at: tge.scheduled_at,
      scheduled_pipeline_id: tge.scheduled_pipeline_id
    }
  end

  def decide_status(%{processed: false}), do: "processing"

  def decide_status(%{processing_result: result}),
    do: result |> Atom.to_string() |> String.downcase()

  defp form_list_page(promotions, list_response) do
    promotions
    |> add_additional_fields(list_response)
    |> to_page()
    |> ToTuple.ok()
  end

  defp add_additional_fields(promotions, list_response) do
    [:page_number, :page_size, :total_entries, :total_pages]
    |> Enum.reduce(%{}, fn field, acc ->
      value = list_response |> Map.get(field)
      acc |> Map.put(field, value)
    end)
    |> Map.put(:entries, promotions)
  end

  defp to_page(map), do: struct(Scrivener.Page, map)

  # Trigger

  def process_trigger_response({:ok, trigger_response}) do
    with {:ok, response} <- Proto.to_map(trigger_response),
         :OK <- response.response_status.code do
      {:ok, "Promotion successfully triggered."}
    else
      :NOT_FOUND ->
        trigger_response.response_status |> Map.get(:message) |> ToTuple.user_error()

      :REFUSED ->
        message =
          trigger_response.response_status
          |> Map.get(:message)
          |> refused_message()

        %{code: "REFUSED", message: message} |> ToTuple.refused_error()

      _ ->
        log_invalid_response(trigger_response, "trigger")
    end
  end

  def process_trigger_response(error), do: error

  defp log_invalid_response(response, rpc_method) do
    response
    |> LT.error("Gofer service responded to #{rpc_method} with :ok and invalid data:")

    ToTuple.internal_error("Internal error")
  end

  defp refused_message(message) when is_binary(message) and message != "", do: message
  defp refused_message(_), do: "Promotion request was refused."
end
