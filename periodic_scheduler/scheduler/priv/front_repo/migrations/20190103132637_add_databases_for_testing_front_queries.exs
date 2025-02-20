defmodule Scheduler.FrontRepo.Migrations.AddDatabasesForTestingFrontQueries do
  use Ecto.Migration

  def change do
    create table(:projects, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :name,            :string
      add :organization_id, :uuid
      add :creator_id,      :uuid
    end

    flush()

    create table(:branches, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :project_id,      references(:projects, type: :uuid, on_delete: :delete_all)
      add :name,            :string
    end

    flush()

    create table(:workflows, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :branch_id,       references(:branches, type: :uuid, on_delete: :delete_all)
      add :request,         :map
      add :created_at,      :utc_datetime
    end

    create table(:repositories, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :project_id,      references(:projects, type: :uuid, on_delete: :delete_all)
      add :name,            :string
      add :owner,           :string
    end

    create table(:repo_host_accounts, primary_key: false) do
      add :id,              :uuid,   primary_key: true
      add :user_id,         :uuid
      add :token,           :string
    end
  end
end
