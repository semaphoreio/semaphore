defmodule RepositoryHub.ServiceAccountClient do
  @moduledoc """
  Wrapper for Service Account API Calls
  """

  alias RepositoryHub.Toolkit

  import Toolkit

  alias InternalApi.ServiceAccount.{
    ServiceAccountService,
    DescribeRequest,
    DescribeResponse
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  Returns information about a given service account, including the member it acts for.
  """
  @spec describe(service_account_id :: Ecto.UUID.t(), org_id :: Ecto.UUID.t(), opts()) ::
          Toolkit.tupled_result(DescribeResponse.t())
  def describe(service_account_id, org_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3000)

    channel()
    |> unwrap(fn connection ->
      request = %DescribeRequest{
        service_account_id: service_account_id,
        org_id: org_id
      }

      try do: ServiceAccountService.Stub.describe(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  # Service accounts are served next to the users they belong to, on the same endpoint.
  defp channel do
    Application.fetch_env!(:repository_hub, :user_grpc_server)
    |> GRPC.Stub.connect(
      interceptors: [
        RepositoryHub.Client.RequestIdInterceptor,
        {RepositoryHub.Client.LoggerInterceptor, skip_logs_for: ~w(describe)},
        RepositoryHub.Client.MetricsInterceptor,
        RepositoryHub.Client.RunAsyncInterceptor
      ]
    )
  end
end
