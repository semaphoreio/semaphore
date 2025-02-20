defmodule Zebra.LegacyRepo.Migrations.AddUserIdToDebugs do
  use Ecto.Migration

  def change do
    alter table(:debugs) do
      add(:user_id, :binary_id)
    end
  end
end
