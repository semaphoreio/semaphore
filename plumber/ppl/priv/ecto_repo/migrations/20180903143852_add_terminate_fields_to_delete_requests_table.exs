defmodule Ppl.EctoRepo.Migrations.AddTerminateFieldsToDeleteRequestsTable do
  use Ecto.Migration

  def change do
    alter table(:delete_requests) do
      add :terminate_request, :string
      add :terminate_request_desc, :string
    end
  end
end
