defmodule RepositoryHub.RepositoryIntegratorClient do
  @moduledoc """
  Wrapper for RepositoryIntegrator API Calls
  """

  alias RepositoryHub.Toolkit

  import Toolkit

  alias InternalApi.RepositoryIntegrator

  alias RepositoryIntegrator.{
    RepositoryIntegratorService,
    GetTokenRequest,
    GetTokenResponse
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  Returns information about given user
  """
  @spec get_token(RepositoryIntegrator.IntegrationType.t(), String.t(), opts()) ::
          Toolkit.tupled_result(GetTokenResponse.t())
  def get_token(integration_type, repository_slug, opts \\ []) do
    opts = with_defaults(opts, timeout: 10_000)

    request = %GetTokenRequest{
      repository_slug: repository_slug,
      integration_type: integration_type
    }

    channel()
    |> unwrap(fn connection ->
      try do: RepositoryIntegratorService.Stub.get_token(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    |> unwrap(fn response ->
      token = response.token
      token
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  defp channel do
    Application.fetch_env!(:repository_hub, :repository_integrator_grpc_server)
    |> GRPC.Stub.connect(
      interceptors: [
        RepositoryHub.Client.RequestIdInterceptor,
        {RepositoryHub.Client.LoggerInterceptor, skip_logs_for: ~w(get_token)},
        RepositoryHub.Client.MetricsInterceptor,
        RepositoryHub.Client.RunAsyncInterceptor
      ]
    )
  end
end
