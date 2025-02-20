defmodule RepositoryHub.OrganizationClient do
  @moduledoc """
  Wrapper for Organization API Calls
  """

  alias RepositoryHub.Toolkit

  import Toolkit

  alias InternalApi.Organization.{
    OrganizationService,
    DescribeRequest
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  Returns owner_id for given project
  """
  @spec describe(org_id :: Ecto.UUID.t(), opts()) ::
          Toolkit.tupled_result(InternalApi.Organization.DescribeResponse.t(), String.t())
  def describe(org_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3000)
    request = %DescribeRequest{org_id: org_id}

    channel()
    |> unwrap(fn connection ->
      try do: OrganizationService.Stub.describe(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  defp channel do
    Application.fetch_env!(:repository_hub, :organization_grpc_endpoint)
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
