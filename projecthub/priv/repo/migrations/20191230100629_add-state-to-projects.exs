defmodule Elixir.Projecthub.Repo.Migrations.AddStateToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :state, :string
    end
  end
end
