defmodule Rbac.Store.OIDCUser do
  alias Rbac.Repo.OIDCUser

  import Ecto.Query

  @spec connect_user(String.t(), Ecto.UUID.t()) ::
          {:ok, OIDCUser.t()} | {:error, Ecto.Changeset.t()}
  def connect_user(oidc_user_id, user_id) do
    %OIDCUser{}
    |> Ecto.Changeset.cast(%{oidc_user_id: oidc_user_id, user_id: user_id}, [
      :oidc_user_id,
      :user_id
    ])
    |> Ecto.Changeset.validate_required([:oidc_user_id, :user_id])
    |> Rbac.Repo.insert()
  end

  @spec fetch_by_user_id(Ecto.UUID.t()) :: {:ok, OIDCUser.t()} | {:error, :not_found}
  def fetch_by_user_id(user_id) do
    OIDCUser
    |> where([u], u.user_id == ^user_id)
    |> Rbac.Repo.one()
    |> case do
      nil -> {:error, :not_found}
      oidc_user -> {:ok, oidc_user}
    end
  end
end
