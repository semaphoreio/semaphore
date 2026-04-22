defmodule Rbac.OIDC.User do
  require Logger

  def find_user_by_oidc_id(oidc_user_id) do
    case Rbac.Store.RbacUser.fetch_by_oidc_id(oidc_user_id) do
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

    Rbac.OIDC.User.create_oidc_user(user)

  The following example creates OIDC user with permament password:

    Rbac.OIDC.User.create_oidc_user(user, [password_data: [password: "foo", temporary: false]])

  """
  def create_oidc_user(%Rbac.Repo.RbacUser{} = user, opts \\ []) do
    with {:ok, client} <- Rbac.Api.OIDC.client() do
      Rbac.Api.OIDC.create_oidc_user(client, user, opts)
    end
  end

  def update_oidc_user(oidc_user_id, user, opts \\ []) do
    with {:ok, client} <- Rbac.Api.OIDC.client() do
      Rbac.Api.OIDC.update_oidc_user(client, oidc_user_id, user, opts)
    end
  end

  def delete_oidc_user(oidc_user_id) do
    with {:ok, client} <- Rbac.Api.OIDC.client() do
      Rbac.Api.OIDC.delete_oidc_user(client, oidc_user_id)
    end
  end

  def create_with_oidc_data(%{oidc_user_id: oidc_user_id}) do
    with {:ok, oidc_user} <- get_oidc_user(oidc_user_id),
         {:ok, github} <- get_github_data(oidc_user.github),
         {:ok, bitbucket} <- get_bitbucket_data(oidc_user.bitbucket),
         {:ok, gitlab} <- get_gitlab_data(oidc_user.gitlab),
         {:ok, user} <- create_user(oidc_user_id, oidc_user.email, oidc_user.name),
         _ <- sync_repo_host_acccount_connection(user, github, bitbucket, gitlab) do
      tmp_sync_new_user_with_rbac(user.id)
      {:ok, user}
    else
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp get_github_data(nil), do: {:ok, %{id: nil, login: nil}}

  defp get_github_data(github) do
    case Rbac.Api.Github.user(github.id) do
      {:ok, github} -> {:ok, github}
      {:error, error} -> {:error, error}
    end
  end

  defp get_bitbucket_data(nil), do: {:ok, %{id: nil, login: nil}}

  defp get_bitbucket_data(bitbucket) do
    case Rbac.Api.Bitbucket.user(bitbucket.id) do
      {:ok, bitbucket} -> {:ok, bitbucket}
      {:error, error} -> {:error, error}
    end
  end

  defp get_gitlab_data(nil), do: {:ok, %{id: nil, username: nil}}

  # GitLab username comes directly from the OIDC user federated identity response
  defp get_gitlab_data(gitlab) do
    {:ok, %{id: gitlab.id, username: gitlab.username}}
  end

  defp get_oidc_user(oidc_user_id) do
    {:ok, client} = Rbac.Api.OIDC.client()
    Rbac.Api.OIDC.get_user(client, oidc_user_id)
  end

  defp create_user(oidc_user_id, email, name) do
    Rbac.User.Actions.create(%{oidc_user_id: oidc_user_id, email: email, name: name})
  end

  defp tmp_sync_new_user_with_rbac(user_id) do
    Task.async(fn ->
      Rbac.ProviderRefresher.refresh(user_id)
      Rbac.TempSync.sync_new_user_with_members_table(user_id)
    end)
  end

  defp sync_repo_host_acccount_connection(user, github, bitbucket, gitlab) do
    alias Rbac.FrontRepo.RepoHostAccount

    common = %{
      name: user.name,
      permission_scope: RepoHostAccount.register_scope(),
      token: nil,
      refresh_token: nil
    }

    RepoHostAccount.update_repo_host_account(
      user.id,
      :github,
      %{github_uid: github.id, login: github.login} |> Map.merge(common),
      reset: true
    )

    RepoHostAccount.update_repo_host_account(
      user.id,
      :bitbucket,
      %{github_uid: bitbucket.id, login: bitbucket.login} |> Map.merge(common),
      reset: true
    )

    RepoHostAccount.update_repo_host_account(
      user.id,
      :gitlab,
      %{github_uid: gitlab.id, login: gitlab.username} |> Map.merge(common),
      reset: true
    )

    {:ok, user}
  end
end
