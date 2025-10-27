defmodule PipelinesAPI.PeriodicSchedulerClient.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with PeriodicScheduler service.
  """

  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.PeriodicScheduler.{
    ApplyRequest,
    GetProjectIdRequest,
    DescribeRequest,
    DeleteRequest,
    ListRequest,
    RunNowRequest
  }

  alias InternalApi.PeriodicScheduler.ParameterValue

  # Apply

  def form_apply_request(params, conn) when is_map(params) do
    %{
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, ""),
      requester_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
      yml_definition: params |> Map.get("yml_definition", "")
    }
    |> ApplyRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_apply_request(_, _), do: ToTuple.internal_error("Internal error")

  # GetProjectId

  def form_get_project_id_request(params, conn) when is_map(params) do
    %{
      periodic_id: params |> Map.get("periodic_id", ""),
      project_name: params |> Map.get("project_name", ""),
      organization_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    }
    |> GetProjectIdRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_get_project_id_request(_, _), do: ToTuple.internal_error("Internal error")

  # Describe

  def form_describe_request(params, _conn) when is_map(params) do
    %{
      id: params |> Map.get("periodic_id", "")
    }
    |> DescribeRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_describe_request(_, _), do: ToTuple.internal_error("Internal error")

  # Delete

  def form_delete_request(params, conn) when is_map(params) do
    %{
      id: params |> Map.get("periodic_id", ""),
      requester: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    }
    |> DeleteRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_delete_request(_, _), do: ToTuple.internal_error("Internal error")

  # List

  def form_list_request(params, _conn) when is_map(params) do
    %{
      project_id: params |> Map.get("project_id", ""),
      page: params |> Map.get("page", 1) |> to_int("page"),
      page_size: params |> Map.get("page_size", 30) |> to_int("page_size")
    }
    |> ListRequest.new()
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_list_request(_, _), do: ToTuple.internal_error("Internal error")

  # RunNow

  def form_run_now_request(params, conn) when is_map(params) do
    reference = build_reference(params)

    req =
      %{
        id: params |> Map.get("periodic_id", ""),
        requester: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, ""),
        reference: reference,
        pipeline_file: params |> Map.get("pipeline_file", ""),
        parameter_values: params |> Map.get("parameters", %{}) |> to_param_values()
      }
      |> RunNowRequest.new()
      |> ToTuple.ok()
  catch
    error -> error
  end

  def form_run_now_request(_, _), do: ToTuple.internal_error("Internal error")

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

  defp build_reference(%{"reference" => reference_map} = _params) when is_map(reference_map) do
    reference_type = Map.get(reference_map, "type", "BRANCH")
    reference_name = Map.get(reference_map, "name", "")

    format_reference(String.upcase(reference_type), reference_name)
  end

  defp build_reference(params) do
    branch_name = Map.get(params, "branch", "")
    format_branch_reference(branch_name)
  end

  defp format_reference("TAG", ""), do: ""
  defp format_reference("TAG", name), do: "refs/tags/#{name}"
  defp format_reference("BRANCH", name), do: format_branch_reference(name)

  defp format_branch_reference(""), do: ""
  defp format_branch_reference(name), do: "refs/heads/#{name}"

  defp to_param_values(parameters) do
    Enum.into(parameters, [], &ParameterValue.new(name: elem(&1, 0), value: elem(&1, 1)))
  end
end
