defmodule PipelinesAPI.Pipelines.ValidateYaml do
  @moduledoc false

  alias PipelinesAPI.PipelinesClient
  alias PipelinesAPI.Util.Metrics
  alias PipelinesAPI.Pipelines.Common
  use Plug.Builder

  import PipelinesAPI.Pipelines.Authorize, only: [authorize_create_with_ppl_in_payload: 2]

  plug(:authorize_create_with_ppl_in_payload)
  plug(:validate_yaml)

  def validate_yaml(conn, _opts) do
    Metrics.benchmark("PipelinesAPI.router", ["validate_yaml"], fn ->
      conn.params
      |> PipelinesClient.validate_yaml()
      |> Common.respond(conn)
    end)
  end
end
