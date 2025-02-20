defmodule PipelinesAPI.Promotions.Common do
  @moduledoc """
  Module serves to fetch switch_id for given ppl_id
  """
  use Plug.Builder

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Pipelines.Common

  def get_switch_id(conn, _opts) do
    conn.params
    |> Map.get("pipeline_id", "")
    |> PipelinesClient.describe(%{})
    |> process_response(conn)
  end

  defp process_response({:ok, %{pipeline: pipeline}}, conn) do
    params = Map.put(conn.params, "switch_id", pipeline.switch_id)
    Map.put(conn, :params, params)
  end

  defp process_response(error, conn) do
    error |> Common.respond(conn) |> halt()
  end
end
