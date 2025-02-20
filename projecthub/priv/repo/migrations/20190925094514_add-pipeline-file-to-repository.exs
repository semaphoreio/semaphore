defmodule :"Elixir.Projecthub.Repo.Migrations.Add-pipeline-file-to-repository" do
  use Ecto.Migration

  def change do
    alter table("repositories") do
      add :pipeline_file, :string, default: ".semaphore/semaphore.yml"
    end
  end
end
