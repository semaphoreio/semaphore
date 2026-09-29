defmodule PipelinesAPI.GuardClient do
  @moduledoc """
    Module is used for communication with the Guard service over gRPC.
  """

  alias PipelinesAPI.GuardClient.{GrpcClient, RequestFormatter, ResponseFormatter}
  alias PipelinesAPI.Util.Metrics

  def invite_collaborators(args, conn) do
    Metrics.benchmark("PipelinesAPI.guard_client", ["invite_collaborators"], fn ->
      args
      |> RequestFormatter.form_invite_collaborators_request(conn)
      |> GrpcClient.invite_collaborators()
      |> ResponseFormatter.process_invite_collaborators_response()
    end)
  end
end
