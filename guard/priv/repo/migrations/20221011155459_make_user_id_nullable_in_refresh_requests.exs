defmodule Guard.Repo.Migrations.MakeUserIdNullableInRefreshRequests do
  use Ecto.Migration

  def change do
    alter table(:collaborator_refresh_requests) do
      modify(:requester_user_id, :binary_id, null: true, from: :binary_id)
    end
  end
end
