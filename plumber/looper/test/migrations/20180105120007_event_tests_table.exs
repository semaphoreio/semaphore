defmodule Looper.EctoRepo.Migrations.EventTestsTable do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :state, :string
      add :result, :string
      add :result_reason, :string
      add :in_scheduling, :boolean, default: false
      add :description, :map
      add :recovery_count, :integer, default: 0, null: false
      add :terminate_request, :string
      add :terminate_request_desc, :string
      add :some_id, :string
      add :some_other_id, :string

      timestamps(type: :utc_datetime_usec)
    end
  end
end
