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
end
