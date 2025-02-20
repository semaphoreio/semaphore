defmodule Guard.Repo.Migrations.AddIdTokenToOidcSession do
  use Ecto.Migration

  def change do
    alter table(:oidc_sessions) do
      add :id_token_enc, :bytea, null: true
    end
  end
end
