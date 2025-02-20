defmodule PublicAPI.ErrorRenderer do
  alias Plug.Conn

  @moduledoc """
  This module is called by the `OpenApiSpex.Plug.CastAndValidate` plug
  when validation fails. It renders the errors in the JSONAPI format.
  It differs from the default error renderer in that it adds documentation_url and message fields.
  """

  def init(opts), do: opts

  def call(conn, errors) when is_list(errors) do
    response = %{
      message: "Validation Failed",
      documentation_url: Application.get_env(:public_api, :documentation_url),
      errors: Enum.map(errors, &render_error/1)
    }

    json = Jason.encode!(response)

    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(422, json)
  end

  def call(conn, reason) do
    call(conn, [reason])
  end

  defp render_error(error) do
    pointer = OpenApiSpex.path_to_string(error)

    %{
      title: "Invalid value",
      source: %{
        pointer: pointer
      },
      detail: to_string(error)
    }
  end
end
