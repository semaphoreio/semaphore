defmodule PipelinesAPI.GoferClient.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with Gofer service.
  """

  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Gofer.{
    TriggerRequest,
    EnvVariable,
    ListTriggerEventsRequest
  }

  # List

  def form_list_request(params) when is_map(params) do
    %{
      switch_id: params |> Map.get("switch_id", ""),
      target_name: params |> Map.get("name", ""),
      page: params |> Map.get("page", 1) |> to_int("page"),
      page_size: params |> Map.get("page_size", 10) |> to_int("page_size")
    }
    |> ListTriggerEventsRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_list_params(_), do: ToTuple.internal_error("Internal error")

  defp to_int(val, _field) when is_integer(val), do: val

  defp to_int(val, field) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> invalid_integer(field, val)
    end
  end

  defp to_int(val, field), do: invalid_integer(field, val)

  defp invalid_integer(field, val) do
    "Invalid value of '#{field}' param: #{inspect(val)} - needs to be integer."
    |> ToTuple.user_error()
    |> throw()
  end

  # Trigger

  def form_trigger_request(params) when is_map(params) do
    %{
      switch_id: params |> Map.get("switch_id", ""),
      target_name: params |> Map.get("name", ""),
      override: params |> Map.get("override", false) |> to_bool(),
      request_token: params |> Map.get("request_token", UUID.uuid4()),
      triggered_by: params |> Map.get("user_id", ""),
      env_variables: form_env_vars(params)
    }
    |> TriggerRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_trigger_request(_), do: ToTuple.internal_error("Internal error")

  defp to_bool(val) when is_boolean(val), do: val
  defp to_bool(val) when val in ["true", "false"], do: val |> String.to_atom()

  defp to_bool(val) do
    "Invalid value of 'override' param: #{inspect(val)} - needs to be boolean."
    |> ToTuple.user_error()
    |> throw()
  end

  defp form_env_vars(params) do
    params
    |> Map.drop(["switch_id", "name", "user_id", "override", "request_token", "pipeline_id"])
    |> Enum.map(fn {key, value} ->
      %{name: key, value: value} |> EnvVariable.new()
    end)
  end
end
