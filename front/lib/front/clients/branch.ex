defmodule Front.Clients.Branch do
  require Logger

  alias InternalApi.Branch.BranchService.Stub

  def channel do
    endpoint = Application.fetch_env!(:front, :branch_api_grpc_endpoint)

    {:ok, channel} = endpoint |> GRPC.Stub.connect()
    channel
  end

  def timeout do
    Application.get_env(:front, :default_internal_api_request_timeout, 5_000)
  end

  def metadata do
    nil
  end

  def list(request) do
    Watchman.benchmark("branch.list.duration", fn ->
      response =
        channel()
        |> Stub.list(request, metadata: metadata(), timeout: timeout())

      case response do
        {:ok, _} -> Watchman.increment("branch.list.success")
        {:error, _} -> Watchman.increment("branch.list.failure")
      end

      Logger.debug(fn ->
        """
        branch API list returned response
        #{inspect(response)}
        for request
        #{inspect(request)}
        """
      end)

      response
    end)
  end
end
