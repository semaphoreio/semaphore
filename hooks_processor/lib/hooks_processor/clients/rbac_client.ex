defmodule HooksProcessor.Clients.RBACClient do
  alias InternalApi.RBAC.{RBAC, ListUserPermissionsRequest}
  alias Util.{Metrics, ToTuple}

  require Logger

  defp url, do: Application.get_env(:hooks_processor, :rbac_api_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

  def member?(org_id, user_id) do
    Logger.debug("Calling RBAC API to check membership: org_id: #{org_id} user_id: #{user_id}")

    Metrics.benchmark("HooksProcessor.RBACClient", ["is_member?"], fn ->
      %ListUserPermissionsRequest{
        user_id: user_id,
        org_id: org_id
      }
      |> do_list_user_permissions()
      |> ToTuple.unwrap(fn permissions ->
        case permissions do
          [] -> {:ok, false}
          _ -> {:ok, true}
        end
      end)
    end)
  end

  defp do_list_user_permissions(request) do
    result =
      Wormhole.capture(__MODULE__, :list_user_permissions_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def list_user_permissions_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> RBAC.Stub.list_user_permissions(request, timeout: @grpc_timeout)
    |> process_list_user_permissions_response()
  end

  defp process_list_user_permissions_response({:ok, response}), do: response.permissions |> ToTuple.ok()
  defp process_list_user_permissions_response(error = {:error, _msg}), do: error
  defp process_list_user_permissions_response(error), do: {:error, error}
end
