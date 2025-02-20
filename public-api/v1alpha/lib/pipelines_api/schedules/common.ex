defmodule PipelinesAPI.Schedules.Common do
  @moduledoc """
  Module collects common functions used in schedule related plugs
  """

  use Plug.Builder

  alias PipelinesAPI.Pipelines.Common, as: RespCommon
  alias PipelinesAPI.PeriodicSchedulerClient
  alias Util.ToTuple

  def get_project_id(conn, _opts) do
    conn = transform_params(conn.params, conn)

    conn.params
    |> PeriodicSchedulerClient.get_project_id(conn)
    |> process_response(conn)
  end

  defp process_response({:ok, project_id}, conn) when is_binary(project_id) do
    Plug.Conn.assign(conn, :project_id, project_id)
  end

  defp process_response(error, conn) do
    error |> RespCommon.respond(conn) |> halt()
  end

  defp transform_params(%{"yml_definition" => yml_string}, conn) do
    yml_string
    |> parse()
    |> extract_project_identifiers()
    |> update_conn(conn)
  end

  defp transform_params(_params, conn), do: conn

  defp extract_project_identifiers(definition) do
    %{
      "periodic_id" => definition |> Map.get("metadata", %{}) |> Map.get("id", ""),
      "project_name" => definition |> Map.get("spec", %{}) |> Map.get("project", "")
    }
    |> ToTuple.ok()
  end

  defp update_conn({:ok, params}, conn) do
    params = params |> Map.merge(conn.params)
    Map.put(conn, :params, params)
  end

  defp update_conn(error, conn) do
    error |> RespCommon.respond(conn) |> halt()
  end

  @doc ~S"""
      iex> alias PipelinesAPI.Schedules.Common
      iex> Common.parse("version: v1.0\nmetadata: %{}")
      {:ok, %{"metadata" => "%{}", "version" => "v1.0"}}
  """
  def parse(yaml_string) do
    YamlElixir.read_from_string!(yaml_string)
  rescue
    error ->
      {:error, {:user, {error, yaml_string}}}
  catch
    a, b ->
      {:error, {:user, {{a, b}, yaml_string}}}
  end
end
