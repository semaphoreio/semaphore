defmodule PreFlightChecks.GRPC.Request do
  @moduledoc """
  gRPC requests utility functions
  """
  alias InternalApi.PreFlightChecksHub, as: API

  @typedoc """
  gRPC requests
  """
  @type t() ::
          API.DescribeRequest.t()
          | API.ApplyRequest.t()
          | API.DestroyRequest.t()

  @doc """
  Converts requests to params for EctoRepo
  """
  @spec to_params(API.ApplyRequest.t()) :: map()
  def to_params(%API.ApplyRequest{level: :ORGANIZATION} = request) do
    %{
      organization_id: request.organization_id,
      requester_id: request.requester_id,
      definition: %{
        commands: request |> from_org_pfc(:commands) |> by_default([]),
        secrets: request |> from_org_pfc(:secrets) |> by_default([])
      }
    }
  end

  def to_params(%API.ApplyRequest{level: :PROJECT} = request) do
    %{
      organization_id: request.organization_id,
      project_id: request.project_id,
      requester_id: request.requester_id,
      definition: %{
        commands: from_proj_pfc(request, :commands) |> by_default([]),
        secrets: from_proj_pfc(request, :secrets) |> by_default([]),
        agent: from_proj_pfc(request, :agent) |> maybe_map(&Map.drop(&1, [:__struct__]))
      }
    }
  end

  defp from_org_pfc(request, key),
    do: from_request(request, [:pre_flight_checks, :organization_pfc, key])

  defp from_proj_pfc(request, key),
    do: from_request(request, [:pre_flight_checks, :project_pfc, key])

  defp by_default(value, default), do: value || default

  defp maybe_map(value, fun), do: value && fun.(value)

  defp from_request(request, keys) do
    Enum.reduce_while(keys, Map.from_struct(request), fn key, acc ->
      case acc do
        %{^key => value} -> {:cont, value}
        _no_key_in_map -> {:halt, nil}
      end
    end)
  end
end
