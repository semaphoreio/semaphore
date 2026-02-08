defmodule Guard.OIDC.User do
  require Logger

  def find_user_by_oidc_id(oidc_user_id) do
    case Guard.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) do
      {:ok, user} -> {:ok, user}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  ## Options

  There is one option:

  * `:password_data` - password data
    * this value is an hash with keys
      * `:password` - value of the password
      * `:temporary` - true if user should be prompted to change the password after login

  ## Examples

  The following example creates OIDC user without password:

    Guard.OIDC.User.create_oidc_user(user)

  The following example creates OIDC user with permament password:

    Guard.OIDC.User.create_oidc_user(user, [password_data: [password: "foo", temporary: false]])

  """
  def create_oidc_user(%Guard.Repo.RbacUser{} = user, opts \\ []) do
    with {:ok, client} <- Guard.Api.OIDC.client() do
      Guard.Api.OIDC.create_oidc_user(client, user, opts)
    end
  end

  def update_oidc_user(oidc_user_id, user, opts \\ []) do
    with {:ok, client} <- Guard.Api.OIDC.client() do
      Guard.Api.OIDC.update_oidc_user(client, oidc_user_id, user, opts)
    end
  end

  def delete_oidc_user(oidc_user_id) do
    with {:ok, client} <- Guard.Api.OIDC.client() do
      Guard.Api.OIDC.delete_oidc_user(client, oidc_user_id)
    end
  end

  def create_with_oidc_data(%{oidc_user_id: oidc_user_id}) do
    with {:ok, oidc_user} <- get_oidc_user(oidc_user_id),
         {:ok, github, mode} <- get_github_data(oidc_user.github),
         {:ok, bitbucket} <- get_bitbucket_data(oidc_user.bitbucket),
         {:ok, gitlab} <- get_gitlab_data(oidc_user.gitlab),
         {:ok, repository_providers} <- map_providers(github, bitbucket, gitlab),
         {:ok, user} <-
           create_user(oidc_user_id, oidc_user.email, oidc_user.name, repository_providers) do
      tmp_sync_new_user_with_rbac(user.id)
      {:ok, user, mode}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp map_providers(github, bitbucket, gitlab) do
    providers = Enum.filter([github, bitbucket, gitlab], fn provider -> not is_nil(provider) end)
    {:ok, providers}
  end

  defp get_github_data(nil), do: {:ok, nil, :noop}

  defp get_github_data(github) do
    case Guard.Api.Github.user(github.id) do
      {:ok, github} ->
        provider = %InternalApi.User.RepositoryProvider{
          type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
          login: github.login,
          uid: github.id
        }

        {:ok, provider, :noop}

      {:error, :not_found} ->
        {:ok, nil, :confirm_github}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_bitbucket_data(nil), do: {:ok, nil}

  defp get_bitbucket_data(bitbucket) do
    case Guard.Api.Bitbucket.user(bitbucket.id) do
      {:ok, bitbucket} ->
        provider = %InternalApi.User.RepositoryProvider{
          type: InternalApi.User.RepositoryProvider.Type.value(:BITBUCKET),
          login: bitbucket.login,
          uid: bitbucket.id
        }

        {:ok, provider}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_gitlab_data(nil), do: {:ok, nil}

  # GitLab username comes direcly from the OIDC user federated identity response
  defp get_gitlab_data(gitlab) do
    {:ok,
     %InternalApi.User.RepositoryProvider{
       type: InternalApi.User.RepositoryProvider.Type.value(:GITLAB),
       login: gitlab.username,
       uid: gitlab.id
     }}
  end

  defp get_oidc_user(oidc_user_id) do
    {:ok, client} = Guard.Api.OIDC.client()
    Guard.Api.OIDC.get_user(client, oidc_user_id)
  end

  defp create_user(oidc_user_id, email, name, repository_providers) do
    Guard.User.Actions.create(%{
      oidc_user_id: oidc_user_id,
      email: email,
      name: name,
      repository_providers: repository_providers
    })
  end

  defp tmp_sync_new_user_with_rbac(user_id) do
    Task.async(fn ->
      # User Updated Consumer should Refresh Providers related to RBAC
      Guard.Events.UserUpdated.publish(user_id, "user_exchange", "updated")
      Guard.Rbac.TempSync.sync_new_user_with_members_table(user_id)
    end)
  end

end
