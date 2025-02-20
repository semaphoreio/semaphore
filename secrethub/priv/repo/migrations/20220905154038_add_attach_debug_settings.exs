defmodule Secrethub.Repo.Migrations.AddAttachDebugSettings do
  use Ecto.Migration

  def change do
    alter table(:secrets) do
      add :job_debug, :int, default: 0
      add :job_attach, :int, default: 0
    end
  end
end
