defmodule Gofer.EctoRepo.Migrations.ChangeTargetsAutoPromoteWhenMaxLength do
  use Ecto.Migration

  def change do
    alter table(:targets) do
      modify :auto_promote_when, :text
    end
  end
end
