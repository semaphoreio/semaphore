defmodule PipelinesAPI.Validator do
  @moduledoc """
  Validates values received through http API
  """

  alias PipelinesAPI.Util.ToTuple
  alias InternalApi.Plumber.ScheduleRequest.ServiceType

  @schedule_request_required_fields ~w(service ppl_request_token owner repo_name hook_id
      branch_name commit_sha client_id client_secret access_token project_id branch_id
      snapshot_archive organization_id)
  @schedule_request_optional_fields ~w(definition_file)

  def validate_post_pipelines(params) do
    @schedule_request_required_fields
    |> Enum.reduce({:ok, %{}}, fn field, acc -> field_present?(acc, params, field) end)
    |> add_optional_fields(params)
  end

  def hide_secret(value), do: :erlang.md5(value) |> Base.encode16(case: :lower)

  defp field_present?(error = {:error, _message}, _, _), do: error

  defp field_present?({:ok, result}, params, field_name) do
    case retrive_value(params, field_name) do
      nil ->
        "Missing field #{field_name} in pipeline schedule request" |> ToTuple.user_error()

      {:error, {:service, val}} ->
        "Invalid value for service field: #{val}" |> ToTuple.user_error()

      value ->
        result |> Map.put(field_name, value) |> ToTuple.ok()
    end
  end

  defp retrive_value(map, "service"), do: map |> Map.get("service") |> service2int()

  defp retrive_value(map = %{"service" => "snapshot"}, "snapshot_archive") do
    map |> Map.get("snapshot_archive")
  end

  defp retrive_value(_map, "snapshot_archive"), do: ""

  defp retrive_value(map, key), do: Map.get(map, key, nil)

  defp service2int(nil), do: nil

  defp service2int(service) do
    service |> String.upcase() |> String.to_atom() |> ServiceType.value()
  rescue
    _ ->
      {:error, {:service, service}}
  end

  defp add_optional_fields({:ok, request}, params) do
    params
    |> Map.take(@schedule_request_optional_fields)
    |> Enum.into(%{})
    |> Map.merge(request)
    |> ToTuple.ok()
  end

  defp add_optional_fields(error, _params), do: error
end
