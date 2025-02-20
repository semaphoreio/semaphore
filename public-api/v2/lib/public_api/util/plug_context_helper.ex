defmodule PublicAPI.Util.PlugContextHelper do
  @moduledoc """
  Helper module for PublicAPI handlers and plugs.
  """
  @resource_key :public_api_resource
  @response_key :public_api_response

  def set_response(resp, conn)

  def set_response({:ok, page = %{entries: _, page_size: _}}, conn) do
    conn
    |> Plug.Conn.assign(
      @response_key,
      struct(PublicAPI.Util.Page, page) |> PublicAPI.Util.ToTuple.ok()
    )
  end

  def set_response(resp, conn) do
    conn |> Plug.Conn.assign(@response_key, resp)
  end

  def get_response(conn) do
    conn.assigns[@response_key]
  end

  def get_request_ids(conn) do
    org_id = conn.assigns[:organization_id]
    user_id = conn.assigns[:user_id]

    %{org_id: org_id, user_id: user_id}
  end

  def set_resource(resource, conn) do
    conn |> Plug.Conn.assign(@resource_key, resource)
  end

  def get_resource(conn) do
    conn.assigns[@resource_key] || get_response(conn)
  end

  def get_resource_id(conn) do
    get_resource(conn) |> id()
  end

  defp id({:ok, %{metadata: %{id: id}}}), do: id
  defp id({:ok, %{id: id}}), do: id
  defp id(_), do: nil

  @spec get_id_and_name(id_or_name :: String.t()) :: {id :: String.t(), name :: String.t()}
  def get_id_and_name(id_or_name) do
    UUID.info(id_or_name)
    |> case do
      {:ok, _info} -> {id_or_name, ""}
      {:error, _} -> {"", id_or_name}
    end
  end
end
