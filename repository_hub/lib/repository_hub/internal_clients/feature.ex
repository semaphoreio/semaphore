defmodule RepositoryHub.FeatureClient do
  @moduledoc """
  Wrapper for FeatureHub API Calls
  """

  alias RepositoryHub.Toolkit

  import Toolkit

  alias InternalApi.Feature.{
    FeatureService,
    ListOrganizationFeaturesRequest,
    ListOrganizationFeaturesResponse
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  Returns a list of features for the organization
  """
  @spec list_organization_features(org_id :: Ecto.UUID.t(), opts()) ::
          Toolkit.tupled_result(ListOrganizationFeaturesResponse.t(), String.t())
  def list_organization_features(org_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3000)
    request = %ListOrganizationFeaturesRequest{org_id: org_id}

    channel()
    |> unwrap(fn connection ->
      FeatureService.Stub.list_organization_features(connection, request, opts)
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  defp channel do
    Application.fetch_env!(:repository_hub, :feature_grpc_endpoint)
    |> GRPC.Stub.connect(
      interceptors: [
        RepositoryHub.Client.RequestIdInterceptor,
        RepositoryHub.Client.LoggerInterceptor,
        RepositoryHub.Client.MetricsInterceptor,
        RepositoryHub.Client.RunAsyncInterceptor
      ]
    )
  end
end
