defmodule PublicAPI.Plugs.Respond do
  @behaviour Plug
  @moduledoc """
  Plug that calls the PublicAPI.Util.Response module to respond to the request.
  It takes the schema of the object and casts it to the schema. (renders the response object)

  The response object should be set in conn.private[:response] by the plugs
  that are preceding this plug.

  """
  import PublicAPI.Util.PlugContextHelper
  require Logger

  @impl true
  def init(opts) do
    unless Keyword.has_key?(opts, :schema) do
      raise ArgumentError, "The schema option is required"
    end

    opts |> Keyword.put(:schema, get_schema(opts[:schema]))
  end

  defp get_schema(schema) when is_nil(schema) or is_map(schema), do: schema
  defp get_schema(schema), do: schema.schema()

  @impl true
  def call(conn, opts) do
    response = get_response(conn)
    render_response(conn, response, opts)
  end

  defp render_response(conn, {:ok, page = %PublicAPI.Util.Page{}}, opts) do
    entries = select_and_cast(opts[:schema], page.entries)
    response = %{page | entries: entries}
    conn |> respond(response)
  end

  defp render_response(conn, {:ok, response}, opts) when is_list(response) do
    select_and_cast(opts[:schema], response)
    conn |> respond(response)
  end

  defp render_response(conn, {:ok, _}, schema: nil) do
    conn |> respond(nil)
  end

  defp render_response(conn, {:ok, response}, opts) do
    select_and_cast(opts[:schema], response)
    |> case do
      {:ok, response_payload} ->
        conn |> respond(response_payload)

      {:error, error} ->
        Logger.error("Error casting response object: #{inspect(error)}")
        conn |> err_formatting()
    end
  end

  defp render_response(conn, response = {:error, _}, _opts) do
    response
    |> PublicAPI.Util.Response.respond(conn)
  end

  defp respond(conn, payload = %PublicAPI.Util.Page{}) do
    PublicAPI.Util.Response.respond_paginated({:ok, payload}, conn)
  end

  defp respond(conn, payload) do
    PublicAPI.Util.Response.respond({:ok, payload}, conn)
  end

  defp select_and_cast(schema = %{type: :array}, response) do
    item_schema = schema.items

    entries =
      response
      |> Enum.reduce([], fn item, acc ->
        select_and_cast(item_schema, item)
        |> case do
          {:ok, item} ->
            [item | acc]

          {:error, error} ->
            Logger.error("Entry ommited from result, cast failed: #{inspect(error)}")
            acc
        end
      end)

    entries
  end

  defp select_and_cast(schema, response) do
    properties = schema |> properties()

    response_selected = response |> Map.take(properties)

    spec = PublicAPI.ApiSpec.spec()

    response_selected
    |> OpenApiSpex.cast_value(schema, spec)
  end

  defp properties(schema = %OpenApiSpex.Reference{}) do
    spec = PublicAPI.ApiSpec.spec()

    OpenApiSpex.resolve_schema(schema, spec.components.schemas)
    |> OpenApiSpex.Schema.properties()
    |> Keyword.keys()
  end

  defp properties(schema) do
    OpenApiSpex.Schema.properties(schema) |> Keyword.keys()
  end

  defp err_formatting(conn) do
    %{message: "Semaphore could not format the response"}
    |> PublicAPI.Util.ToTuple.internal_error()
    |> PublicAPI.Util.Response.respond(conn)
  end
end
