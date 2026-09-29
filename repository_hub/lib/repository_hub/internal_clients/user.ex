defmodule RepositoryHub.UserClient do
  @moduledoc """
  Wrapper for User API Calls
  """

  alias RepositoryHub.Toolkit

  import Toolkit

  alias InternalApi.User.{
    UserService,
    GetRepositoryTokenRequest,
    DescribeRequest,
    DescribeResponse
  }

  @type opts() :: [
          timeout: non_neg_integer()
        ]

  @doc """
  Returns information about given user
  """
  @spec describe(user_id :: Ecto.UUID.t(), opts()) :: Toolkit.tupled_result(DescribeResponse.t())
  def describe(user_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3000)

    channel()
    |> unwrap(fn connection ->
      request = %DescribeRequest{
        user_id: user_id
      }

      try do: UserService.Stub.describe(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    |> unwrap_error(fn
      %{message: message} -> error(message)
      message when is_bitstring(message) -> error(message)
      other -> error(inspect(other))
    end)
  end

  @doc """
  Returns repository provider logins connected to given user based on provider_type
  """
  @spec get_repository_provider_logins(
          provider_type :: InternalApi.User.RepositoryProvider.Type.t(),
          user_id :: Ecto.UUID.t(),
          opts()
        ) ::
          Toolkit.tupled_result([String.t()])
  def get_repository_provider_logins(provider_type, user_id, opts \\ []) do
    describe(user_id, opts)
    |> unwrap(fn user ->
      user.repository_providers
      |> Enum.filter(fn provider ->
        provider.scope != :NONE &&
          provider.type == provider_type
      end)
      |> Enum.map(fn provider -> provider.login end)
      |> wrap()
    end)
  end

  @doc """
  Returns repository provider uids connected to given user based on provider_type
  """
  @spec get_repository_provider_uids(
          provider_type :: InternalApi.User.RepositoryProvider.Type.t(),
          user_id :: Ecto.UUID.t(),
          opts()
        ) ::
          Toolkit.tupled_result([String.t()])
  def get_repository_provider_uids(provider_type, user_id, opts \\ []) do
    describe(user_id, opts)
    |> unwrap(fn user ->
      user.repository_providers
      |> Enum.filter(fn provider ->
        provider.scope != :NONE &&
          provider.type == provider_type
      end)
      |> Enum.map(fn provider -> provider.uid end)
      |> wrap()
    end)
  end

  @doc """
  Returns repository token for given user
  """
  @spec get_repository_token(
          integration_type :: binary(),
          user_id :: Ecto.UUID.t(),
          opts()
        ) ::
          Toolkit.ok_tuple() | Toolkit.err_tuple()
  def get_repository_token(integration_type, user_id, opts \\ []) do
    opts = with_defaults(opts, timeout: 3_000)

    request = %GetRepositoryTokenRequest{
      user_id: user_id,
      integration_type: to_integration_type(integration_type)
    }

    channel()
    |> unwrap(fn connection ->
      try do: UserService.Stub.get_repository_token(connection, request, opts),
          after: GRPC.Stub.disconnect(connection)
    end)
    # credo:disable-for-next-line
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

  @spec to_integration_type(binary) :: InternalApi.RepositoryIntegrator.IntegrationType.t()
  defp to_integration_type(value) do
    value
    |> String.upcase()
    |> String.to_atom()
  end

  defp channel do
    Application.fetch_env!(:repository_hub, :user_grpc_server)
    |> GRPC.Stub.connect(
      interceptors: [
        RepositoryHub.Client.RequestIdInterceptor,
        {RepositoryHub.Client.LoggerInterceptor, skip_logs_for: ~w(describe get_repository_token)},
        RepositoryHub.Client.MetricsInterceptor,
        RepositoryHub.Client.RunAsyncInterceptor
      ]
    )
  end
end
