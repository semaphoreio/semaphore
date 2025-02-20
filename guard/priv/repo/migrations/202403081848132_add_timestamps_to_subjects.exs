defmodule Guard.Repo.Migrations.AddTimestampsToSubjects do
  use Ecto.Migration

  def change do
    alter table(:subjects) do
      add_if_not_exists :inserted_at, :utc_datetime, default: fragment("now()")
      add_if_not_exists :updated_at, :utc_datetime, default: fragment("now()")
      add_if_not_exists :name, :string
      add_if_not_exists :type, :string
    end
  end
end
