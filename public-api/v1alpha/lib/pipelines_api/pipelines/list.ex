defmodule PipelinesAPI.Pipelines.List do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder

  import PipelinesAPI.Workflows.WfAuthorize, only: [wf_authorize_read_list: 2]
  import PipelinesAPI.Workflows.WfAuthorize.AuthorizeParams, only: [get_initial_ppl_id: 2]
  import PipelinesAPI.Workflows.WfAuthorize.ValidateRequiredParams, only: [validate_params: 2]

  plug(:validate_params)
  plug(:get_initial_ppl_id)
  plug(:wf_authorize_read_list)
  plug(:list)

  def list(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["list"], fn ->
      conn.params
      |> PipelinesClient.list()
      |> Common.respond_paginated(conn)
    end)
  end
end
