defmodule Zebra.LegacyRepo.Migrations.AddBuildRequestIdToBuildsTable do
  use Ecto.Migration

  def change do
    alter table(:builds) do
      add :build_request_id, :binary_id
    end
  end
end
