defmodule Projecthub.Models.User do
  require Logger
  defstruct [:id, :name, :github_token, :github_uid, :github_login, :avatar_url]

  def find(user_id, metadata \\ nil) do
    req = InternalApi.User.DescribeRequest.new(user_id: user_id)
    {:ok, res} = InternalApi.User.UserService.Stub.describe(channel(), req, options(metadata))

    if res.status.code == :OK do
      construct_from_describe(res)
    else
      nil
    end
  end

  def check_github_permissions(login, repo, token) do
    client = Tentacat.Client.new(%{access_token: token})

    resp = Tentacat.get("repos/#{repo.owner}/#{repo.name}/collaborators/#{login}/permission", client)

    case resp do
      {200, %{"permission" => "admin"}, _} ->
        {:ok, :admin}

      {200, _, _} ->
        {:error, :permissions_not_an_admin}

      {401, _, _} ->
        {:error, :permissions_unauthorized}

      {403, %{"message" => "Must have push access to view collaborator permission."}, _} ->
        {:error, :permissions_not_an_admin}

      {403,
       %{
         "message" =>
           "Resource protected by organization SAML enforcement. You must grant your OAuth token access to this organization."
       }, _} ->
        {:error, :permissions_saml_enforcement}

      {404, _, _} ->
        {:error, :permissions_not_found}

      {_, _, resp} ->
        Logger.error(
          "Error while fetching permissions about #{login} from #{repo.owner}/#{repo.name} on github: #{inspect(resp)}"
        )

        {:error, :permissions_not_fetched}
    end
  end

  defp construct_from_describe(raw_user) do
    %__MODULE__{
      :id => raw_user.user_id,
      :name => raw_user.name,
      :github_token => raw_user.github_token,
      :github_login => raw_user.github_login
    }
  end

  defp channel do
    GRPC.Stub.connect(Application.fetch_env!(:projecthub, :user_grpc_endpoint),
      interceptors: [
        Projecthub.Util.GRPC.ClientRequestIdInterceptor,
        {
          Projecthub.Util.GRPC.ClientLoggerInterceptor,
          skip_logs_for: ~w(
            describe
          )
        },
        Projecthub.Util.GRPC.ClientRunAsyncInterceptor
      ]
    )
    |> case do
      {:ok, channel} -> channel
      _ -> nil
    end
  end

  defp options(metadata) do
    [timeout: 30_000, metadata: metadata]
  end
end
