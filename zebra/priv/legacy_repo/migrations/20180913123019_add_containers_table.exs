defmodule Zebra.Repo.Migrations.AddContainersTable do
  use Ecto.Migration

  def change do
    create table(:containers) do
      add :job_id, :binary_id
      add :build_server_id, :binary_id
      add :aasm_state, :string
      add :cores, :integer
      add :created_at, :utc_datetime
      add :updated_at, :utc_datetime
    end

    create index(:containers, [:aasm_state, :build_server_id, :job_id])
  end
end
