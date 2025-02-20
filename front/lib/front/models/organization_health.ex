defmodule Front.Models.OrganizationHealth do
  @moduledoc """
  This model is used to fetch organization health data for a specific organization.
  """

  alias Front.Clients.Velocity, as: VelocityClient
  alias InternalApi.Velocity, as: API
  require Logger

  def list(project_ids, org_id, from, to) do
    VelocityClient.fetch_organization_health(%API.OrganizationHealthRequest{
      project_ids: project_ids,
      org_id: org_id,
      from_date: to_grpc_timestamp(from),
      to_date: to_grpc_timestamp(to)
    })
    |> case do
      {:ok, response} ->
        {:ok, response}

      error ->
        Logger.error("Error fetch organization health: #{inspect(error)}")
        error
    end
  end

  @spec to_grpc_timestamp(date :: Date.t()) :: Google.Protobuf.Timestamp.t()
  defp to_grpc_timestamp(date) do
    Google.Protobuf.Timestamp.new(%{
      seconds: Timex.to_unix(date)
    })
  end
end
