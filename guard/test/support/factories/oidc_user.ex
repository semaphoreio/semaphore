defmodule Support.Factories.OIDCUser do
  def insert(user_id \\ Ecto.UUID.generate(), oidc_user_id \\ Ecto.UUID.generate()) do
    %Guard.Repo.OIDCUser{user_id: user_id, oidc_user_id: oidc_user_id}
    |> Guard.Repo.insert()
  end
end
