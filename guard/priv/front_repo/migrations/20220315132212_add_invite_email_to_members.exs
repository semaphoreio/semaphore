defmodule Guard.FrontRepo.Migrations.AddInviteEmailToMembers do
  use Ecto.Migration

  def change do
    alter table(:members) do
      add :invite_email, :string
    end
  end
end
