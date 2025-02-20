defmodule PipelinesAPI.Workflows.List do
  @moduledoc false

  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  alias InternalApi.PlumberWF.{ListRequest, WorkflowService}

  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_read_list: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]
  import PipelinesAPI.Workflows.WfAuthorize.ValidateRequiredParams, only: [validate_params: 2]

  @timeout 16_000

  plug(:validate_params)
  plug(:get_initial_ppl_id)
  plug(:authorize_read_list)
  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["wf_list"], fn ->
      conn.params
      |> do_list()
      |> Common.respond_paginated(conn)
    end)
  end

  defp do_list(params) do
    with {:ok, page} <- non_zero_value_or_default(params, "page", 1),
         {:ok, page_size} <- non_zero_value_or_default(params, "page_size", 30),
         {:ok, request} <- form_list_request(params, page, page_size),
         do: do_list_(request)
  end

  defp form_list_request(params, page, page_size) do
    p =
      params
      |> Map.put("page", page)
      |> Map.put("page_size", page_size)
      |> Map.replace("created_after", seconds: to_int(params["created_after"]))
      |> Map.replace("created_before", seconds: to_int(params["created_before"]))

    Util.Proto.deep_new(ListRequest, p, string_keys_to_atoms: true)
  end

  defp do_list_(request) do
    Wormhole.capture(__MODULE__, :list_, [request],
      stacktrace: true,
      ok_tuple: true,
      timeout: @timeout
    )
    |> workflows_to_entries()
  end

  def list_(list_request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    WorkflowService.Stub.list(channel, list_request)
  end

  # Scrivener.Headers requires list of entries to be called :entries
  defp workflows_to_entries({:ok, resp}) do
    e = Map.get(resp, :workflows)
    {:ok, Map.put(resp, :entries, e)}
  end

  defp workflows_to_entries(err), do: err

  defp url(), do: System.get_env("WF_GRPC_URL")

  # Util

  defp non_zero_value_or_default(map, key, default) do
    case Map.get(map, key) do
      value when is_binary(value) -> int_value_or_default(value, default)
      _ -> {:ok, default}
    end
  end

  defp int_value_or_default(value, default) do
    case Integer.parse(value) do
      {num, _} when is_integer(num) and num > 0 -> {:ok, num}
      _ -> {:ok, default}
    end
  end

  defp to_int(nil), do: nil
  defp to_int(string), do: Integer.parse(string) |> elem(0)
end
