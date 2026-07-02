defmodule PipelinesAPI.ServiceAccountClient.RequestFormatter do
  @moduledoc false
  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.ServiceAccount.{
    CreateRequest,
    ListRequest,
    DescribeRequest,
    UpdateRequest,
    DestroyRequest,
    DeactivateRequest,
    ReactivateRequest,
    RegenerateTokenRequest
  }

  def form_create_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")
    creator_id = Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0, "")
    name = Map.get(params, "name", "")
    description = Map.get(params, "description", "")

    if name == "" do
      ToTuple.user_error("Name must be provided")
    else
      CreateRequest.new(
        org_id: org_id,
        name: name,
        description: description,
        creator_id: creator_id
      )
      |> ToTuple.ok()
    end
  catch
    error -> error
  end

  def form_create_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_list_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    ListRequest.new(
      org_id: org_id,
      page_size: params |> Map.get("page_size", 100) |> to_int("page_size"),
      page_token: params |> Map.get("page_token", "") |> to_page_token()
    )
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_list_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_describe_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    DescribeRequest.new(service_account_id: Map.get(params, "id", ""), org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_describe_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_update_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    UpdateRequest.new(
      service_account_id: Map.get(params, "id", ""),
      name: Map.get(params, "name", ""),
      description: Map.get(params, "description", ""),
      org_id: org_id
    )
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_update_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_destroy_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    DestroyRequest.new(service_account_id: Map.get(params, "id", ""), org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_destroy_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_deactivate_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    DeactivateRequest.new(service_account_id: Map.get(params, "id", ""), org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_deactivate_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_reactivate_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    ReactivateRequest.new(service_account_id: Map.get(params, "id", ""), org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_reactivate_request(_, _), do: ToTuple.internal_error("Internal error")

  def form_regenerate_token_request(params, conn) when is_map(params) do
    org_id = Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0, "")

    RegenerateTokenRequest.new(service_account_id: Map.get(params, "id", ""), org_id: org_id)
    |> ToTuple.ok()
  catch
    error -> error
  end

  def form_regenerate_token_request(_, _), do: ToTuple.internal_error("Internal error")

  defp to_int(val, _field) when is_integer(val), do: val

  defp to_int(val, field) do
    case Integer.parse(val) do
      {n, ""} ->
        n

      _ ->
        "Invalid value of '#{field}' param: #{inspect(val)} - needs to be integer."
        |> ToTuple.user_error()
        |> throw()
    end
  end

  defp to_page_token(""), do: ""

  defp to_page_token(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} when n >= 0 ->
        val

      _ ->
        "Invalid value of 'page_token' param: #{inspect(val)} - must be a non-negative integer."
        |> ToTuple.user_error()
        |> throw()
    end
  end

  defp to_page_token(_), do: ""
end
