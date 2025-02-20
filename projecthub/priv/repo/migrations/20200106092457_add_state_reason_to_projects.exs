defmodule Projecthub.Repo.Migrations.AddStateReasonToProjects do
  use Ecto.Migration

  def change do
    alter table("projects") do
      add :state_reason, :string
    end
  end
end
